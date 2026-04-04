require "yaml"
require "set"

class Dish < ApplicationRecord
  SPICE_LABEL = "スパイス・ハーブ"
  TASTE_LABEL = "味覚・刺激"
  SCENE_LABEL = "シーン"
  TIME_LABEL = "時間帯"
  SEASON_LABEL = "季節"
  GENRE_LABEL = "ジャンル"
  SPICE_PAIRINGS_PATH = Rails.root.join("config/spice_pairings.yml")
  LABEL_NORMALIZATION_TARGETS = {
    "スパイス・ハーブ" => SPICE_LABEL,
    "味覚・刺激" => TASTE_LABEL,
    "シーン" => SCENE_LABEL,
    "時間帯" => TIME_LABEL,
    "季節" => SEASON_LABEL,
    "ジャンル" => GENRE_LABEL
  }.freeze
  NO_BENTO_PATTERN = /ラーメン|うどん|そうめん|ひやむぎ|ざるそば|冷やし中華|パスタ|フォー|スープ|みそ汁|おでん|すき焼き|しゃぶしゃぶ|刺身|寿司|海鮮丼|鉄火丼|ちらし寿司|手巻き寿司|かき氷|アイス|ゼリー|プリン|スムージー|ハーブティー|チャイ|スパイスコーラ/.freeze
  BENTO_FRIENDLY_PATTERN = /生姜焼き|唐揚げ|ハンバーグ|オムライス|焼きそば|チャーハン|チキンカツ|鶏の照り焼き|野菜炒め|春巻き|エビフライ|チキン南蛮|ホットドッグ|サンドイッチ|おにぎり|タコライス/.freeze
  HOME_STYLE_PATTERN = /みそ汁|おかゆ|納豆ご飯|卵かけご飯|肉じゃが|野菜炒め|焼き魚|湯豆腐|冷奴|おでん|茶碗蒸し|浅漬け|酢の物|芋煮|芋の子汁|わかめスープ|卵スープ|コンソメスープ|コーンスープ|春雨スープ|ミネストローネ|クラムチャウダー|シリアル|トースト|ホットサンド|オムレツ|フルーツヨーグルト|オートミール|サラダ|豆腐サラダ|海藻サラダ|ポテトサラダ|フルーツサラダ|おにぎり|お茶漬け|スムージー|ハーブティー|チャイ/.freeze
  EATING_OUT_PATTERN = /寿司|刺身|天ぷら|すき焼き|しゃぶしゃぶ|焼き鳥|うな重|ラーメン|ピザ|ハンバーガー|ステーキ|グラタン|ドリア|ラザニア|ローストチキン|ローストビーフ|エビチリ|麻婆豆腐|トムヤムクン|ナン|タンドリー|ガパオ|パッタイ|ビビンバ|チヂミ|プルコギ|タコス|ブリトー|カルパッチョ|カプレーゼ/.freeze
  HOME_ONLY_PATTERN = /みそ汁|おかゆ|納豆ご飯|卵かけご飯|スムージー|ハーブティー|チャイ|ちらし寿司/.freeze

  has_many :category_contents, dependent: :destroy
  has_many :categories, through: :category_contents
  has_one_attached :image

  # カテゴリ名から料理を検索
  scope :by_category, ->(category_name) {
    joins(:categories).where(categories: { name: category_name })
  }

  def self.search_by_conditions(params)
    ensure_condition_labels_integrity!
    scope = Dish.all
    scope = scope.where("dishes.name ILIKE ?", "%#{params[:keyword]}%")   if params[:keyword].present?
    scope = scope.by_category(params[:category])                          if params[:category].present?
    scope = filter_by_scene(scope, params[:scene])                        if params[:scene].present?
    scope = filter_by_label(scope, TIME_LABEL, params[:time_of_day])      if params[:time_of_day].present?
    scope = filter_by_label(scope, SEASON_LABEL, params[:season])         if params[:season].present?
    scope = filter_by_label(scope, GENRE_LABEL, params[:genre])           if params[:genre].present?
    selected_spice = Array(params[:spice_name]).compact_blank.first
    if selected_spice.present?
      spice_labels = [ SPICE_LABEL, nil, "" ]
      spice_dish_ids = Dish.joins(:category_contents)
                           .joins(:categories)
                           .where(categories: { name: selected_spice })
                           .where(category_contents: { label: spice_labels })
                           .distinct
                           .pluck(:id)
      scope = scope.where(id: spice_dish_ids)
    end
    if params[:taste].present?
      taste_name = params[:taste]
      taste_dish_ids = Dish.joins(:category_contents)
                           .joins(:categories)
                           .where(category_contents: { label: TASTE_LABEL }, categories: { name: taste_name })
                           .distinct
                           .pluck(:id)
      scope = scope.where(id: taste_dish_ids)
    end
    scope
  end

  def self.filter_by_scene(scope, scene)
    scene_dish_ids = Dish.joins(:category_contents)
                         .joins(:categories)
                         .where(category_contents: { label: SCENE_LABEL }, categories: { name: scene })
                         .distinct
                         .pluck(:id)
    scope.where(id: scene_dish_ids)
  end

  def self.filter_by_label(scope, label, name)
    ids = Dish.joins(:category_contents)
              .joins(:categories)
              .where(category_contents: { label: label }, categories: { name: name })
              .distinct
              .pluck(:id)
    scope.where(id: ids)
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
    ensure_condition_labels_integrity!
    by_category(category_name).order("RANDOM()").first
  end

  def self.scene_names_for(dish_name)
    name = dish_name.to_s
    return [ "内食" ] if name.blank?

    scenes = []
    scenes << "弁当" if name.match?(BENTO_FRIENDLY_PATTERN)
    scenes << "内食" if name.match?(HOME_STYLE_PATTERN)
    scenes << "外食" if name.match?(EATING_OUT_PATTERN)
    scenes -= [ "弁当" ] if name.match?(NO_BENTO_PATTERN)

    if name.match?(HOME_ONLY_PATTERN)
      scenes -= [ "外食", "弁当" ]
      scenes << "内食"
    end

    scenes = [ "内食" ] if scenes.empty?
    scenes.uniq
  end

  def self.ensure_condition_labels_integrity!
    return unless Rails.env.production?
    return if @condition_labels_integrity_verified

    (@condition_labels_integrity_mutex ||= Mutex.new).synchronize do
      return if @condition_labels_integrity_verified

      normalized_count = normalize_condition_labels!
      backfilled_count = backfill_missing_scene_and_taste_labels!
      spice_synced_count = sync_spice_links_if_available!
      @condition_labels_integrity_verified = true

      Rails.logger.info(
        "[Dish.ensure_condition_labels_integrity!] normalized=#{normalized_count} backfilled=#{backfilled_count} spice_synced=#{spice_synced_count}"
      )
    end
  rescue StandardError => e
    Rails.logger.error("[Dish.ensure_condition_labels_integrity!] failed: #{e.class}: #{e.message}")
  end

  def self.normalize_condition_labels!
    normalized_count = 0

    CategoryContent.where.not(label: nil).find_each do |content|
      normalized_label = normalize_label(content.label)
      next if normalized_label == content.label

      existing = CategoryContent.find_by(
        dish_id: content.dish_id,
        category_id: content.category_id,
        label: normalized_label
      )

      if existing
        content.destroy!
      else
        content.update!(label: normalized_label)
      end

      normalized_count += 1
    end

    normalized_count
  end

  def self.normalize_label(raw_label)
    compacted = raw_label.to_s.delete(" \u3000")
    LABEL_NORMALIZATION_TARGETS.fetch(compacted, raw_label)
  end

  def self.backfill_missing_scene_and_taste_labels!
    category_links = CategoryContent.where(label: [ SCENE_LABEL, TASTE_LABEL ]).pluck(:dish_id, :label)
    labels_by_dish_id = Hash.new { |hash, key| hash[key] = Set.new }
    category_links.each { |dish_id, label| labels_by_dish_id[dish_id] << label }

    backfilled_dish_count = 0

    Dish.find_each do |dish|
      existing_labels = labels_by_dish_id[dish.id]
      added_any = false

      unless existing_labels.include?(SCENE_LABEL)
        scene_names_for(dish.name).each do |scene_name|
          add_label_link!(dish: dish, label: SCENE_LABEL, category_name: scene_name)
        end
        added_any = true
      end

      unless existing_labels.include?(TASTE_LABEL)
        tastes_for_name(dish.name).each do |taste_name|
          add_label_link!(dish: dish, label: TASTE_LABEL, category_name: taste_name)
        end
        added_any = true
      end

      backfilled_dish_count += 1 if added_any
    end

    backfilled_dish_count
  end

  def self.add_label_link!(dish:, label:, category_name:)
    category = Category.find_or_create_by!(name: category_name)
    CategoryContent.find_or_create_by!(dish_id: dish.id, category_id: category.id, label: label)
  end

  def self.sync_spice_links_if_available!
    mappings = spice_pairings
    if mappings.blank?
      Rails.logger.warn("[Dish.sync_spice_links_if_available!] skipped: spice_pairings is empty")
      return 0
    end

    sync_spice_pairings!
  end
end
