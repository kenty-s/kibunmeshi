class SearchHistoriesController < ApplicationController
  before_action :authenticate_user!

  def index
    @search_histories = current_user.search_histories.recent.includes(dish: { category_contents: :category })
  end

  def trends
    scope = current_user.search_histories.includes(dish: { category_contents: :category })
    @heatmap = build_time_mood_heatmap(scope)
    @spice_summary = build_spice_summary(scope)
  end

  def destroy
    history = current_user.search_histories.find(params[:id])
    history.destroy
    redirect_to search_histories_path, notice: "削除しました"
  end

  private

  def build_time_mood_heatmap(scope)
    time_labels = %w[朝 昼 夜]
    mood_labels = %w[ガッツリ サッパリ]

    counts = Hash.new(0)
    scope.find_each do |history|
      params = history.query_params || {}

      mood = params["category"].presence || params["mood"].presence
      if mood.blank?
        mood = history.dish&.categories&.map(&:name)&.find { |v| mood_labels.include?(v.to_s) }
      end
      next unless mood_labels.include?(mood)

      time = time_label_from_timestamp(history.executed_at || history.created_at)
      next unless time_labels.include?(time)

      counts[[ time, mood ]] += 1
    end

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

  def time_label_from_timestamp(timestamp)
    hour = timestamp.in_time_zone.hour
    return "朝" if hour >= 5 && hour < 11
    return "昼" if hour >= 11 && hour < 17

    "夜"
  end

  def build_spice_summary(scope)
    counts = Hash.new(0)

    scope.find_each do |history|
      spice_names = extract_spice_names(history)
      spice_names.each { |name| counts[name] += 1 }
    end

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

  def extract_spice_names(history)
    params = history.query_params || {}
    spice_param = params["spice_name"].presence || params["spice_names"]
    spice_names = Array(spice_param).compact_blank

    if spice_names.empty?
      spice_names = history.dish&.category_contents&.select { |cc| cc.label == "スパイス/ハーブ" }
        &.map { |cc| cc.category&.name }
      spice_names = Array(spice_names).compact_blank
    end

    if spice_names.empty? && history.dish
      spice_names = history.dish.spice_names_for_display
    end

    spice_names.uniq
  end
end
