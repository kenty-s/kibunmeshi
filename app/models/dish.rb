class Dish < ApplicationRecord
  SPICE_LABEL = "スパイス/ハーブ"

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
    scope = scope.where("time_of_days @> ?",      [ params[:time_of_day] ].to_json)        if params[:time_of_day].present?
    scope = scope.where("seasons @> ?",           [ params[:season] ].to_json)             if params[:season].present?
    scope = scope.where("moods @> ?",             [ params[:mood] ].to_json)               if params[:mood].present?
    scope = scope.where("genres @> ?",            [ params[:genre] ].to_json)              if params[:genre].present?
    scope = scope.where("cooking_styles @> ?",    [ params[:cooking_style] ].to_json)      if params[:cooking_style].present?
    scope = scope.where("healthiness_types @> ?", [ params[:healthiness_type] ].to_json)   if params[:healthiness_type].present?
    if params[:spice_name].present?
      spice_dish_ids = Dish.joins(:categories)
                           .where(categories: { name: params[:spice_name] })
                           .select(:id)
      scope = scope.where(id: spice_dish_ids)
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
      when /カレーライス|グリーンカレー|バターチキンカレー|キーマカレー|カツカレー|タンドリーチキン/
        %w[クミン コリアンダー ターメリック カルダモン 唐辛子]
      when /タコス|タコライス|ブリトー/
        %w[クミン コリアンダー パプリカ]
      when /ガパオライス|トムヤムクン|パッタイ|フォー/
        %w[唐辛子 コリアンダー バジル]
      when /麻婆豆腐/
        %w[五香粉 山椒 唐辛子]
      when /エビチリ/
        %w[唐辛子]
      when /酢豚|回鍋肉|青椒肉絲|餃子|春巻き|エビマヨ|野菜炒め/
        %w[ガーリック]
      when /チャーハン/
        %w[ガーリック ブラックペッパー]
      when /焼売|シュウマイ/
        %w[からし]
      when /卵スープ/
        %w[ブラックペッパー]
      when /ペペロンチーノ/
        %w[ガーリック 唐辛子]
      when /たらこパスタ/
        %w[わさび]
      when /ミートソースパスタ|ナポリタン|ピザ/
        %w[オレガノ バジル]
      when /カルボナーラ/
        %w[ブラックペッパー]
      when /きのこパスタ/
        %w[タイム]
      when /グラタン|シチュー|ドリア|ラザニア/
        %w[ナツメグ]
      when /コンソメスープ|ミネストローネ/
        %w[ローレル]
      when /コーンスープ|クラムチャウダー/
        %w[ホワイトペッパー]
      when /ハンバーグ/
        %w[ナツメグ ブラックペッパー]
      when /ステーキ|ローストチキン|ローストビーフ|チキンソテー/
        %w[ローズマリー ブラックペッパー]
      when /ロコモコ|ベーコンエッグ|オムレツ|オムライス|ハンバーガー/
        %w[ブラックペッパー]
      when /ホットドッグ|ホットサンド|サンドイッチ/
        %w[マスタード]
      when /とんかつ|おでん/
        %w[からし]
      when /唐揚げ/
        %w[ガーリック 生姜]
      when /チキンカツ/
        %w[からし]
      when /チキン南蛮|エビフライ|かつ丼|天ぷら|天丼/
        %w[唐辛子]
      when /寿司|刺身|海鮮丼|鉄火丼|手巻き寿司|ちらし寿司/
        %w[わさび]
      when /カルパッチョ/
        %w[ホワイトペッパー ブラックペッパー]
      when /うな重|焼き魚/
        %w[山椒]
      when /豚の角煮/
        %w[ガーリック 生姜 からし]
      when /親子丼/
        %w[唐辛子]
      when /牛丼|肉じゃが|豚の角煮|鶏の照り焼き|生姜焼き|山形風芋煮|宮城風芋煮|芋の子汁|茶碗蒸し|お茶漬け|おかゆ|みそ汁|わかめスープ|春雨スープ|湯豆腐|冷奴|水ナスの浅漬け|浅漬け|酢の物|納豆ご飯|卵かけご飯|おにぎり/
        %w[生姜]
      when /ラーメン|冷やし中華|焼きそば|お好み焼き|たこ焼き|かしみん焼き|ざるそば|うどん|そうめん|ひやむぎ|焼き鳥/
        %w[唐辛子]
      when /ナン/
        %w[カルダモン]
      when /プルコギ|ビビンバ|チヂミ/
        %w[唐辛子 ガーリック]
      when /サラダ|シーザーサラダ|コブサラダ|豆腐サラダ|海藻サラダ|ポテトサラダ|カプレーゼ|フルーツサンド/
        %w[パセリ]
      when /パンケーキ|フレンチトースト|フルーツヨーグルト|シリアル|オートミール|スムージー|フルーツサラダ|かき氷|アイスクリーム|プリン|ゼリー|トースト/
        %w[シナモン]
      when /スパイスコーラ/
        %w[シナモン クローブ カルダモン]
      when /チャイ/
        %w[シナモン カルダモン]
      when /スパイスクッキー/
        %w[シナモン ナツメグ]
      else
        []
      end

    spices.uniq
  end
  # PostgreSQLのRANDOM関数でランダムに並び替えて1件取得
  def self.random_by_category(category_name)
    by_category(category_name).order("RANDOM()").first
  end
end
