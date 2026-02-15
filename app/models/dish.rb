class Dish < ApplicationRecord
  SPICE_LABEL = "スパイス/ハーブ"
  TASTE_LABEL = "味覚/刺激"

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
    scope = scope.where("time_of_days @> ?",      [params[:time_of_day]].to_json)        if params[:time_of_day].present?
    scope = scope.where("seasons @> ?",           [params[:season]].to_json)             if params[:season].present?
    scope = scope.where("moods @> ?",             [params[:mood]].to_json)               if params[:mood].present?
    scope = scope.where("genres @> ?",            [params[:genre]].to_json)              if params[:genre].present?
    scope = scope.where("cooking_styles @> ?",    [params[:cooking_style]].to_json)      if params[:cooking_style].present?
    scope = scope.where("healthiness_types @> ?", [params[:healthiness_type]].to_json)   if params[:healthiness_type].present?
    if params[:spice_name].present?
      spice_dish_ids = Dish.joins(:categories)
                           .where(categories: { name: params[:spice_name] })
                           .select(:id)
      scope = scope.where(id: spice_dish_ids)
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

  def spice_names_for_display(fallback_names: [])
    names = category_contents.includes(:category).where(label: SPICE_LABEL).map { |cc| cc.category.name }
    return names if names.present?

    fallback = Array(fallback_names).compact_blank
    return fallback if fallback.present?

    self.class.spices_for_name(name)
  end

  def self.spices_for_name(dish_name)
    return [] if dish_name.blank?

    spices =
      case dish_name
      when /カレー|タンドリー|キーマ|グリーンカレー|バターチキン|カツカレー/
        %w[クミン コリアンダー ターメリック カルダモン 唐辛子]
      when /タコス|ブリトー|タコライス/
        %w[クミン コリアンダー パプリカ 唐辛子]
      when /ガパオ|トムヤムクン|パッタイ|フォー/
        %w[唐辛子 コリアンダー クミン バジル]
      when /麻婆|回鍋肉|青椒肉絲|酢豚|チャーハン|餃子|春巻き|エビチリ|エビマヨ|春雨スープ|卵スープ|ラーメン|冷やし中華/
        %w[五香粉 唐辛子 生姜 ガーリック ブラックペッパー]
      when /ビビンバ|プルコギ|チヂミ/
        %w[唐辛子 ガーリック ブラックペッパー 生姜]
      when /オムライス/
        %w[ブラックペッパー パセリ バジル オレガノ]
      when /クラムチャウダー|コーンスープ|カルパッチョ/
        %w[ホワイトペッパー ブラックペッパー]
      when /パスタ|ピザ|ナポリタン|カプレーゼ|グラタン|ドリア|ラザニア|ミネストローネ|コンソメスープ|シチュー/
        %w[バジル オレガノ ローレル ブラックペッパー]
      when /ペペロンチーノ/
        %w[ガーリック 唐辛子 オレガノ ブラックペッパー]
      when /ステーキ|ハンバーグ|ロースト|チキンソテー|ロコモコ|ホットサンド/
        %w[ブラックペッパー ガーリック ローズマリー タイム]
      when /牛丼|親子丼|かつ丼|天丼/
        %w[唐辛子 生姜]
      when /とんかつ|唐揚げ|チキンカツ|エビフライ|天ぷら/
        %w[ブラックペッパー パプリカ ガーリック]
      when /寿司|刺身|海鮮丼|鉄火丼|手巻き寿司|ちらし寿司|焼き魚|うな重/
        %w[山椒 生姜]
      when /おでん|肉じゃが|豚の角煮|鶏の照り焼き|生姜焼き|芋煮|湯豆腐|冷奴|お茶漬け|おかゆ|みそ汁|茶碗蒸し/
        %w[生姜 唐辛子]
      when /スムージー|フルーツ|ヨーグルト|シリアル|フルーツサンド|プリン|フレンチトースト|パンケーキ|アイス|ゼリー|かき氷/
        %w[シナモン ナツメグ カルダモン クローブ]
      when /スパイスコーラ/
        %w[シナモン クローブ カルダモン 生姜]
      when /サラダ|シーザーサラダ|カプレーゼ|サンドイッチ|トースト/
        %w[バジル パセリ ブラックペッパー]
      when /そば|うどん|そうめん|ひやむぎ|焼きそば|お好み焼き|たこ焼き/
        %w[唐辛子 生姜]
      else
        %w[ブラックペッパー]
      end

    spices.uniq
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
