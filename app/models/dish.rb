require "yaml"

class Dish < ApplicationRecord
  SPICE_LABEL = "スパイス/ハーブ"
  LEGACY_SPICE_LABEL = "スパイス・ハーブ"
  TASTE_LABEL = "味覚/刺激"
  SCENE_LABEL = "シーン"
  SPICE_PAIRINGS_PATH = Rails.root.join("config/spice_pairings.yml")

  has_many :category_contents, dependent: :destroy
  has_many :categories, through: :category_contents
  has_one_attached :image

  # カテゴリ名から料理を検索
  scope :by_category, ->(category_name) {
    joins(:categories).where(categories: { name: category_name })
  }

  def self.search_by_conditions(params)
    scope = Dish.all
    scope = scope.where("dishes.name ILIKE ?", "%#{params[:keyword]}%")   if params[:keyword].present?
    scope = scope.by_category(params[:category])                          if params[:category].present?
    scope = filter_by_scene(scope, params[:scene])                        if params[:scene].present?
    scope = scope.where("time_of_days @> ?",      [ params[:time_of_day] ].to_json)        if params[:time_of_day].present?
    scope = scope.where("seasons @> ?",           [ params[:season] ].to_json)             if params[:season].present?
    scope = scope.where("moods @> ?",             [ params[:mood] ].to_json)               if params[:mood].present?
    scope = scope.where("genres @> ?",            [ params[:genre] ].to_json)              if params[:genre].present?
    scope = scope.where("cooking_styles @> ?",    [ params[:cooking_style] ].to_json)      if params[:cooking_style].present?
    scope = scope.where("healthiness_types @> ?", [ params[:healthiness_type] ].to_json)   if params[:healthiness_type].present?
    selected_spice = Array(params[:spice_name]).compact_blank.first
    if selected_spice.present?
      spice_labels = [ SPICE_LABEL, LEGACY_SPICE_LABEL, nil, "" ]
      spice_dish_ids = Dish.joins(:category_contents)
                           .joins(:categories)
                           .where(categories: { name: selected_spice })
                           .where(category_contents: { label: spice_labels })
                           .distinct
                           .pluck(:id)
      if spice_dish_ids.present?
        scope = scope.where(id: spice_dish_ids)
      else
        fallback_names = spice_pairings.filter_map do |dish_name, spice_names|
          dish_name if Array(spice_names).include?(selected_spice)
        end
        scope = fallback_names.present? ? scope.where(name: fallback_names) : scope.none
      end
    end
    if params[:taste].present?
      taste_name = params[:taste]
      taste_dish_ids = Dish.joins(:category_contents)
                           .joins(:categories)
                           .where(category_contents: { label: TASTE_LABEL }, categories: { name: taste_name })
                           .distinct
                           .pluck(:id)
      if taste_dish_ids.present?
        scope = scope.where(id: taste_dish_ids)
      else
        fallback_ids = Dish.select(:id, :name).filter_map { |dish| dish.id if tastes_for_name(dish.name).include?(taste_name) }
        scope = scope.where(id: fallback_ids)
      end
    end
    scope
  end

  def self.filter_by_scene(scope, scene)
    scene_dish_ids = Dish.joins(:category_contents)
                         .joins(:categories)
                         .where(category_contents: { label: SCENE_LABEL }, categories: { name: scene })
                         .distinct
                         .pluck(:id)
    return scope.where(id: scene_dish_ids) if scene_dish_ids.present?

    case scene
    when "外食"
      scope.where("time_of_days @> ? OR time_of_days @> ?", [ "昼" ].to_json, [ "夜" ].to_json)
    when "弁当"
      scope.where("time_of_days @> ?", [ "昼" ].to_json)
    when "内食"
      scope.where("time_of_days @> ? OR time_of_days @> ?", [ "朝" ].to_json, [ "夜" ].to_json)
    else
      scope
    end
  end

  def spice_names_for_display(fallback_names: [])
    names = category_contents.includes(:category).where(label: SPICE_LABEL).map { |cc| cc.category.name }
    return names if names.present?

    fallback = Array(fallback_names).compact_blank
    return fallback if fallback.present?

    self.class.spices_for_name(name)
  end

  def self.spices_for_name(dish_name)
    return [] if dish_name.blank?

    spice_pairings.fetch(dish_name.to_s, [])
  end

  def self.spice_pairings
    @spice_pairings ||= begin
      raw = YAML.safe_load(File.read(SPICE_PAIRINGS_PATH), permitted_classes: [], aliases: false) || {}
      raw.transform_values { |names| Array(names).compact_blank.uniq }
    end
  rescue Errno::ENOENT
    {}
  end

  def self.reload_spice_pairings!
    @spice_pairings = nil
    spice_pairings
  end

  def self.sync_spice_pairings!(dish_names: nil)
    mappings = spice_pairings
    target_names = Array(dish_names).compact_blank
    scope = target_names.present? ? where(name: target_names) : all
    synced = 0

    scope.find_each do |dish|
      spice_names = Array(mappings[dish.name]).compact_blank.uniq
      existing_names = dish.category_contents.includes(:category).where(label: SPICE_LABEL).map { |cc| cc.category.name }.uniq
      next if existing_names.sort == spice_names.sort

      transaction do
        CategoryContent.where(dish: dish, label: SPICE_LABEL).delete_all
        spice_names.each do |spice_name|
          category = Category.find_or_create_by!(name: spice_name)
          CategoryContent.create!(dish: dish, category: category, label: SPICE_LABEL)
        end
      end
      synced += 1
    end

    synced
  end

  def self.tastes_for_name(dish_name)
    return [] if dish_name.blank?

    return %w[甘い] if dish_name.match?(/パンケーキ|フレンチトースト|かき氷|アイス|プリン|ゼリー|フルーツ|シリアル|スムージー|チャイ|スパイスコーラ|スパイスクッキー/)

    tastes = []
    tastes << "すっぱい" if dish_name.match?(/酢豚|酢の物|浅漬け|冷やし中華|トムヤムクン|カプレーゼ|カルパッチョ/)
    tastes << "辛い" if dish_name.match?(/カレー|タンドリー|麻婆|エビチリ|ペペロンチーノ|担々|ガパオ|トムヤムクン|タコス|ブリトー|タコライス|ビビンバ|チヂミ|プルコギ|キムチ/)
    tastes << "苦い" if dish_name.match?(/海藻サラダ|シーザーサラダ|コブサラダ|豆腐サラダ|サラダ|ゴーヤ/)
    tastes << "しょっぱい"
    tastes.uniq
  end
  # PostgreSQLのRANDOM関数でランダムに並び替えて1件取得
  def self.random_by_category(category_name)
    by_category(category_name).order("RANDOM()").first
  end
end
