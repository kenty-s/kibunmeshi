class SearchHistoriesController < ApplicationController
  before_action :authenticate_user!

  def index
    @search_histories = current_user.search_histories
      .recent
      .includes(dish: [ :categories, { category_contents: :category } ])
      .page(params[:page])
      .per(10)
  end

  def trends
    scope = current_user.search_histories.includes(dish: [ :categories, { category_contents: :category } ])
    cache_key = [
      "search_histories/trends/v4",
      current_user.id,
      current_user.search_histories.maximum(:updated_at)&.to_i,
      current_user.search_histories.count
    ]
    summaries = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      build_trend_summaries(scope)
    end
    summaries = normalize_trend_summaries(summaries)

    @heatmap = summaries[:heatmap]
    @time_mood_spice_heatmap = summaries[:time_mood_spice_heatmap]
    @spice_summary = summaries[:spice_summary]
    @kibunmeshi_summary = summaries[:kibunmeshi_summary]
  end

  def destroy
    history = current_user.search_histories.find(params[:id])
    history.destroy
    redirect_to search_histories_path, notice: "削除しました"
  end

  private

  def build_time_mood_heatmap_from_counts(counts, time_labels, mood_labels)
    cells = mood_labels.to_h do |mood|
      row = time_labels.to_h { |time| [ time, counts[[ time, mood ]] || 0 ] }
      [ mood, row ]
    end

    color_set = {
      "ガッツリ" => { fill: "rgba(155, 28, 20, 0.75)", border: "rgba(139, 24, 18, 1)" },
      "サッパリ" => { fill: "rgba(66, 160, 56, 0.75)", border: "rgba(54, 132, 46, 1)" }
    }

    chart_data = {
      labels: time_labels,
      datasets: mood_labels.map do |mood|
        {
          label: mood,
          data: time_labels.map { |time| counts[[ time, mood ]] || 0 },
          backgroundColor: color_set[mood][:fill],
          borderColor: color_set[mood][:border],
          borderWidth: 1
        }
      end
    }

    {
      time_labels: time_labels,
      mood_labels: mood_labels,
      cells: cells,
      max_count: counts.values.max.to_i,
      total: counts.values.sum,
      chart_data: chart_data
    }
  end

  def build_time_mood_spice_heatmap_from_counts(counts, time_labels, mood_labels)
    totals_by_mood = Hash.new(0)
    totals_by_mood_and_spice = Hash.new(0)
    counts.each do |(mood, _, spice_name), count|
      totals_by_mood[mood] += count
      totals_by_mood_and_spice[[ mood, spice_name ]] += count
    end

    rows_by_mood = mood_labels.to_h do |mood|
      spice_names = totals_by_mood_and_spice
        .select { |(row_mood, _), _| row_mood == mood }
        .sort_by { |(_, _), count| -count }
        .first(8)
        .map { |(key, _)| key.last }

      rows = spice_names.map do |spice_name|
        row_counts = time_labels.to_h { |time| [ time, counts[[ mood, time, spice_name ]] || 0 ] }
        { name: spice_name, counts: row_counts, total: row_counts.values.sum }
      end

      [ mood, rows ]
    end

    {
      time_labels: time_labels,
      mood_labels: mood_labels,
      rows_by_mood: rows_by_mood,
      totals_by_mood: totals_by_mood,
      max_count: counts.values.max.to_i,
      total: counts.values.sum
    }
  end

  def build_spice_summary_from_counts(counts)
    sorted = counts.sort_by { |_, count| -count }
    top = sorted.first(5)
    total = counts.values.sum
    other = total - top.sum { |_, count| count }

    items = top.map { |name, count| { name: name, count: count } }
    items << { name: "その他", count: other } if other.positive?

    if total.positive?
      ratios = items.map { |item| item[:count].to_f / total * 100.0 }
      rounded = ratios.map { |ratio| ratio.round }
      diff = 100 - rounded.sum
      if diff != 0 && rounded.any?
        remainders = ratios.map { |ratio| ratio - ratio.floor }
        target_index =
          if diff > 0
            remainders.each_with_index.max_by { |value, _| value }&.last
          else
            remainders.each_with_index.min_by { |value, _| value }&.last
          end
        if target_index
          rounded[target_index] += diff
        end
      end

      items.each_with_index do |item, index|
        item[:ratio] = ratios[index].round(2)
        item[:ratio_display] = rounded[index]
      end
    end

    {
      items: items,
      total: total
    }
  end

  def build_kibunmeshi_summary_from_counts(dish_counts, dishes_by_id)
    total = dish_counts.values.sum
    sorted = dish_counts
      .sort_by { |(dish_id, count)| [ -count, dishes_by_id[dish_id]&.name.to_s ] }
      .first(10)

    items = []
    previous_count = nil
    current_rank = 0

    sorted.each_with_index do |(dish_id, count), index|
      current_rank = index + 1 if previous_count != count
      dish = dishes_by_id[dish_id]

      items << {
        rank: current_rank,
        dish: dish,
        name: dish&.name.to_s,
        mood: extract_dish_mood(dish),
        count: count,
        ratio: total.positive? ? (count.to_f / total * 100.0).round(1) : 0
      }

      previous_count = count
    end

    { items: items, total: total }
  end

  def build_trend_summaries(scope)
    time_labels = %w[朝 昼 夜]
    mood_labels = %w[ガッツリ サッパリ]
    time_mood_counts = Hash.new(0)
    mood_time_spice_counts = Hash.new(0)
    spice_counts = Hash.new(0)
    dish_counts = Hash.new(0)
    dishes_by_id = {}
    dish_metadata_cache = {}

    scope.find_each do |history|
      spice_names = extract_spice_names(history, dish_metadata_cache)
      spice_names.each { |name| spice_counts[name] += 1 }

      dish = history.dish
      if dish
        dish_counts[dish.id] += 1
        dishes_by_id[dish.id] ||= dish
      end

      mood = extract_mood(history, mood_labels, dish_metadata_cache)
      next unless mood_labels.include?(mood)

      times = extract_times(history, time_labels, dish_metadata_cache)
      next if times.empty?

      times.each { |time| time_mood_counts[[ time, mood ]] += 1 }
      next if spice_names.empty?

      spice_names.each do |spice_name|
        times.each { |time| mood_time_spice_counts[[ mood, time, spice_name ]] += 1 }
      end
    end

    {
      heatmap: build_time_mood_heatmap_from_counts(time_mood_counts, time_labels, mood_labels),
      time_mood_spice_heatmap: build_time_mood_spice_heatmap_from_counts(mood_time_spice_counts, time_labels, mood_labels),
      spice_summary: build_spice_summary_from_counts(spice_counts),
      kibunmeshi_summary: build_kibunmeshi_summary_from_counts(dish_counts, dishes_by_id)
    }
  end

  def normalize_trend_summaries(raw_summaries)
    summaries = raw_summaries.is_a?(Hash) ? raw_summaries.deep_symbolize_keys : {}

    heatmap = summaries[:heatmap].is_a?(Hash) ? summaries[:heatmap].deep_symbolize_keys : {}
    time_mood_spice_heatmap = summaries[:time_mood_spice_heatmap].is_a?(Hash) ? summaries[:time_mood_spice_heatmap].deep_symbolize_keys : {}
    spice_summary = summaries[:spice_summary].is_a?(Hash) ? summaries[:spice_summary].deep_symbolize_keys : {}
    kibunmeshi_summary = summaries[:kibunmeshi_summary].is_a?(Hash) ? summaries[:kibunmeshi_summary].deep_symbolize_keys : {}

    {
      heatmap: {
        time_labels: Array(heatmap[:time_labels]),
        mood_labels: Array(heatmap[:mood_labels]),
        cells: heatmap[:cells].is_a?(Hash) ? heatmap[:cells] : {},
        max_count: heatmap[:max_count].to_i,
        total: heatmap[:total].to_i,
        chart_data: heatmap[:chart_data].is_a?(Hash) ? heatmap[:chart_data] : { labels: [], datasets: [] }
      },
      time_mood_spice_heatmap: {
        time_labels: Array(time_mood_spice_heatmap[:time_labels]),
        mood_labels: Array(time_mood_spice_heatmap[:mood_labels]),
        rows_by_mood: time_mood_spice_heatmap[:rows_by_mood].is_a?(Hash) ? time_mood_spice_heatmap[:rows_by_mood] : {},
        totals_by_mood: time_mood_spice_heatmap[:totals_by_mood].is_a?(Hash) ? time_mood_spice_heatmap[:totals_by_mood] : {},
        max_count: time_mood_spice_heatmap[:max_count].to_i,
        total: time_mood_spice_heatmap[:total].to_i
      },
      spice_summary: {
        items: Array(spice_summary[:items]),
        total: spice_summary[:total].to_i
      },
      kibunmeshi_summary: {
        items: Array(kibunmeshi_summary[:items]),
        total: kibunmeshi_summary[:total].to_i
      }
    }
  end

  def extract_spice_names(history, dish_metadata_cache = nil)
    params = history.query_params || {}
    spice_param = params["spice_name"].presence || params["spice_names"]
    spice_names = Array(spice_param).compact_blank

    if spice_names.empty?
      spice_names = dish_metadata(history.dish, dish_metadata_cache)[:spice_names]
      spice_names = Array(spice_names).compact_blank
    end

    if spice_names.empty? && history.dish
      spice_names = Dish.spices_for_name(history.dish.name)
    end

    spice_names.uniq
  end

  def extract_mood(history, mood_labels, dish_metadata_cache = nil)
    params = history.query_params || {}
    mood = params["category"].presence || params["mood"].presence

    if mood.blank?
      mood = dish_metadata(history.dish, dish_metadata_cache)[:mood]
    end

    mood
  end

  def extract_times(history, time_labels, dish_metadata_cache = nil)
    params = history.query_params || {}
    times = Array(params["time_of_day"]).compact_blank

    if times.blank?
      times = Array(dish_metadata(history.dish, dish_metadata_cache)[:times]).compact_blank
    end

    times & time_labels
  end

  def dish_metadata(dish, dish_metadata_cache = nil)
    return { mood: nil, spice_names: [], times: [] } unless dish

    cache = dish_metadata_cache || {}
    cache[dish.id] ||= begin
      contents = dish.category_contents.to_a
      mood = contents
        .select { |cc| cc.label == "気分" }
        .map { |cc| cc.category&.name.to_s }
        .find { |name| %w[ガッツリ サッパリ].include?(name) }
      spice_names = contents
        .select { |cc| cc.label == "スパイス/ハーブ" }
        .map { |cc| cc.category&.name.to_s }
        .compact_blank
        .uniq

      times = Array(dish.time_of_days).compact_blank
      if times.blank?
        times = contents
          .select { |cc| cc.label == "時間帯" }
          .map { |cc| cc.category&.name.to_s }
          .compact_blank
      end

      {
        mood: mood,
        spice_names: spice_names,
        times: times
      }
    end
  end

  def extract_dish_mood(dish)
    dish_metadata(dish)[:mood]
  end
end
