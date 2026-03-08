class BackfillMissingSceneAndTasteLabels < ActiveRecord::Migration[7.2]
  class Dish < ApplicationRecord
    self.table_name = "dishes"
  end

  class Category < ApplicationRecord
    self.table_name = "categories"
  end

  class CategoryContent < ApplicationRecord
    self.table_name = "category_contents"
  end

  SCENE_LABEL = "シーン".freeze
  TASTE_LABEL = "味覚/刺激".freeze

  NO_BENTO_PATTERN = /ラーメン|うどん|そうめん|ひやむぎ|ざるそば|冷やし中華|パスタ|フォー|スープ|みそ汁|おでん|すき焼き|しゃぶしゃぶ|刺身|寿司|海鮮丼|鉄火丼|ちらし寿司|手巻き寿司|かき氷|アイス|ゼリー|プリン|スムージー|ハーブティー|チャイ|スパイスコーラ/.freeze
  BENTO_FRIENDLY_PATTERN = /生姜焼き|唐揚げ|ハンバーグ|オムライス|焼きそば|チャーハン|チキンカツ|鶏の照り焼き|野菜炒め|春巻き|エビフライ|チキン南蛮|ホットドッグ|サンドイッチ|おにぎり|タコライス/.freeze
  HOME_STYLE_PATTERN = /みそ汁|おかゆ|納豆ご飯|卵かけご飯|肉じゃが|野菜炒め|焼き魚|湯豆腐|冷奴|おでん|茶碗蒸し|浅漬け|酢の物|芋煮|芋の子汁|わかめスープ|卵スープ|コンソメスープ|コーンスープ|春雨スープ|ミネストローネ|クラムチャウダー|シリアル|トースト|ホットサンド|オムレツ|フルーツヨーグルト|オートミール|サラダ|豆腐サラダ|海藻サラダ|ポテトサラダ|フルーツサラダ|おにぎり|お茶漬け|スムージー|ハーブティー|チャイ/.freeze
  EATING_OUT_PATTERN = /寿司|刺身|天ぷら|すき焼き|しゃぶしゃぶ|焼き鳥|うな重|ラーメン|ピザ|ハンバーガー|ステーキ|グラタン|ドリア|ラザニア|ローストチキン|ローストビーフ|エビチリ|麻婆豆腐|トムヤムクン|ナン|タンドリー|ガパオ|パッタイ|ビビンバ|チヂミ|プルコギ|タコス|ブリトー|カルパッチョ|カプレーゼ/.freeze
  HOME_ONLY_PATTERN = /みそ汁|おかゆ|納豆ご飯|卵かけご飯|スムージー|ハーブティー|チャイ/.freeze

  def up
    return unless table_exists?(:dishes) && table_exists?(:categories) && table_exists?(:category_contents)

    Dish.reset_column_information
    Category.reset_column_information
    CategoryContent.reset_column_information

    say_with_time "Backfilling missing scene/taste labels for dishes" do
      Dish.connection_pool.with_connection do |connection|
        connection.schema_cache.clear!
        connection.clear_cache!

        connection.unprepared_statement do
          Dish.select(:id, :name).find_each do |dish|
            backfill_scene_labels(dish)
            backfill_taste_labels(dish)
          end
        end
      end
    end
  end

  def down
    # no-op: data backfill migration
  end

  private

  def backfill_scene_labels(dish)
    return if CategoryContent.exists?(dish_id: dish.id, label: SCENE_LABEL)

    scene_names_for(dish.name).each do |scene_name|
      attach_label(dish, SCENE_LABEL, scene_name)
    end
  end

  def backfill_taste_labels(dish)
    return if CategoryContent.exists?(dish_id: dish.id, label: TASTE_LABEL)

    taste_names_for(dish.name).each do |taste_name|
      attach_label(dish, TASTE_LABEL, taste_name)
    end
  end

  def attach_label(dish, label, category_name)
    category = Category.find_or_create_by!(name: category_name)
    CategoryContent.find_or_create_by!(dish_id: dish.id, category_id: category.id, label: label)
  end

  def scene_names_for(dish_name)
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

  def taste_names_for(dish_name)
    name = dish_name.to_s
    return [ "しょっぱい" ] if name.blank?
    return [ "甘い" ] if name.match?(/パンケーキ|フレンチトースト|かき氷|アイス|プリン|ゼリー|フルーツ|シリアル|スムージー|チャイ|スパイスコーラ|スパイスクッキー/)

    tastes = []
    tastes << "すっぱい" if name.match?(/酢豚|酢の物|浅漬け|冷やし中華|トムヤムクン|カプレーゼ|カルパッチョ/)
    tastes << "辛い" if name.match?(/カレー|タンドリー|麻婆|エビチリ|ペペロンチーノ|担々|ガパオ|トムヤムクン|タコス|ブリトー|タコライス|ビビンバ|チヂミ|プルコギ|キムチ/)
    tastes << "苦い" if name.match?(/海藻サラダ|シーザーサラダ|コブサラダ|豆腐サラダ|サラダ|ゴーヤ/)
    tastes << "しょっぱい"
    tastes.uniq
  end
end
