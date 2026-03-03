require "cgi"
require "stringio"
require "zlib"

SEED_VERSION = "2026-03-04-scene-overrides-v5"

unless ActiveRecord::Base.connection.data_source_exists?("seed_runs")
  puts "seed_runs table is missing. Run db:migrate before db:seed."
  exit
end

if SeedRun.exists?(version: SEED_VERSION)
  puts "Seeds already applied for version #{SEED_VERSION}. Skipping."
  exit
end

unless ActiveRecord::Base.connection.data_source_exists?("solid_queue_jobs")
  ActiveJob::Base.queue_adapter = :inline
end

def dish_placeholder_svg(name)
  palette = [
    [ "#2b2118", "#d4a373" ],
    [ "#1f2a24", "#8fc5a2" ],
    [ "#2b2f3a", "#a6c0ff" ],
    [ "#3a2630", "#e6a6b3" ],
    [ "#2a2d20", "#d8c48b" ],
    [ "#2f1f22", "#f0b49c" ]
  ]
  seed = Zlib.crc32(name)
  base, accent = palette[seed % palette.length]
  escaped = CGI.escapeHTML(name)

  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800" viewBox="0 0 1200 800">
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#{base}"/>
          <stop offset="100%" stop-color="#{accent}"/>
        </linearGradient>
      </defs>
      <rect width="1200" height="800" fill="url(#bg)"/>
      <circle cx="1020" cy="140" r="140" fill="rgba(255,255,255,0.18)"/>
      <circle cx="980" cy="620" r="220" fill="rgba(255,255,255,0.12)"/>
      <text x="80" y="140" fill="rgba(255,255,255,0.8)" font-size="28" letter-spacing="6" font-family="'Hiragino Kaku Gothic ProN', 'Yu Gothic', sans-serif">
        KIBUNMESHI
      </text>
      <text x="80" y="260" fill="#ffffff" font-size="96" font-weight="700" font-family="'Hiragino Kaku Gothic ProN', 'Yu Gothic', sans-serif">
        #{escaped}
      </text>
      <rect x="80" y="300" width="220" height="8" rx="4" fill="rgba(255,255,255,0.8)"/>
    </svg>
  SVG
end

SPICE_LABEL = "スパイス/ハーブ"
SPICE_NAMES = Dish.spice_pairings.values.flatten.uniq.freeze
TASTE_LABEL = "味覚/刺激"
TASTE_NAMES = [ "甘い", "すっぱい", "しょっぱい", "苦い", "辛い" ].freeze
SCENE_LABEL = "シーン"
SCENE_NAMES = [ "外食", "弁当", "内食" ].freeze
REMOVED_LABELS = [ "気分詳細", "調理スタイル", "ヘルシーさ" ].freeze
REMOVED_CATEGORY_NAMES = [
  "疲れた", "元気", "リラックス", "集中したい", "特別な日",
  "簡単", "本格的", "温かい", "冷たい",
  "ヘルシー", "こってり", "野菜多め", "タンパク質重視"
].freeze

SCENE_OVERRIDES = {
  "生姜焼き" => [ "外食", "弁当", "内食" ],
  "唐揚げ" => [ "外食", "弁当", "内食" ],
  "ハンバーグ" => [ "外食", "弁当", "内食" ],
  "オムライス" => [ "外食", "弁当", "内食" ],
  "焼きそば" => [ "外食", "弁当", "内食" ],
  "チャーハン" => [ "外食", "弁当", "内食" ],
  "お好み焼き" => [ "外食", "内食" ],
  "春巻き" => [ "弁当", "内食" ],
  "エビフライ" => [ "弁当", "内食" ],
  "ナン" => [ "外食" ],
  "豚の角煮" => [ "内食" ],
  "親子丼" => [ "外食", "内食" ],
  "牛丼" => [ "外食", "内食" ],
  "みそ汁" => [ "内食" ],
  "おかゆ" => [ "内食" ],
  "納豆ご飯" => [ "内食" ],
  "卵かけご飯" => [ "内食" ],
  "スムージー" => [ "内食" ],
  "ハーブティー" => [ "内食" ],
  "チャイ" => [ "内食" ],
  "フルーツサンド" => [ "弁当", "内食" ]
}.freeze

NO_BENTO_PATTERN = /ラーメン|うどん|そうめん|ひやむぎ|ざるそば|冷やし中華|パスタ|フォー|スープ|みそ汁|おでん|すき焼き|しゃぶしゃぶ|刺身|寿司|海鮮丼|鉄火丼|ちらし寿司|手巻き寿司|かき氷|アイス|ゼリー|プリン|スムージー|ハーブティー|チャイ|スパイスコーラ/
BENTO_FRIENDLY_PATTERN = /生姜焼き|唐揚げ|ハンバーグ|オムライス|焼きそば|チャーハン|チキンカツ|鶏の照り焼き|野菜炒め|春巻き|エビフライ|チキン南蛮|ホットドッグ|サンドイッチ|おにぎり|タコライス/
HOME_STYLE_PATTERN = /みそ汁|おかゆ|納豆ご飯|卵かけご飯|肉じゃが|野菜炒め|焼き魚|湯豆腐|冷奴|おでん|茶碗蒸し|浅漬け|酢の物|芋煮|芋の子汁|わかめスープ|卵スープ|コンソメスープ|コーンスープ|春雨スープ|ミネストローネ|クラムチャウダー|シリアル|トースト|ホットサンド|オムレツ|フルーツヨーグルト|オートミール|サラダ|豆腐サラダ|海藻サラダ|ポテトサラダ|フルーツサラダ|おにぎり|お茶漬け|スムージー|ハーブティー|チャイ/
EATING_OUT_PATTERN = /寿司|刺身|天ぷら|すき焼き|しゃぶしゃぶ|焼き鳥|うな重|ラーメン|ピザ|ハンバーガー|ステーキ|グラタン|ドリア|ラザニア|ローストチキン|ローストビーフ|エビチリ|麻婆豆腐|トムヤムクン|ナン|タンドリー|ガパオ|パッタイ|ビビンバ|チヂミ|プルコギ|タコス|ブリトー|カルパッチョ|カプレーゼ/
HOME_ONLY_PATTERN = /みそ汁|おかゆ|納豆ご飯|卵かけご飯|スムージー|ハーブティー|チャイ/

def scene_names_for(food_data)
  name = food_data[:name].to_s
  return SCENE_OVERRIDES[name] if SCENE_OVERRIDES.key?(name)

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

def taste_names_for(food_name)
  names = Dish.tastes_for_name(food_name)
  names.present? ? names : [ "しょっぱい" ]
end

def spice_names_for(food_name)
  Dish.spices_for_name(food_name)
end

def sync_label_tags(dish:, label:, names:)
  CategoryContent.where(dish: dish, label: label).delete_all
  Array(names).compact_blank.uniq.each do |name|
    category = Category.find_by(name: name)
    CategoryContent.find_or_create_by(dish: dish, category: category, label: label) if category
  end
end

# カテゴリを作成（全てのタグをCategoryとして統合）
puts "Creating categories..."

CategoryContent.where(label: REMOVED_LABELS).delete_all
Category.where(name: REMOVED_CATEGORY_NAMES)
        .left_outer_joins(:category_contents)
        .where(category_contents: { id: nil })
        .find_each(&:destroy!)

# キブン
[ 'ガッツリ', 'サッパリ' ].each { |name| Category.find_or_create_by(name: name) }

# 時間帯
[ '朝', '昼', '夜' ].each { |name| Category.find_or_create_by(name: name) }

# 季節
[ '春', '夏', '秋', '冬' ].each { |name| Category.find_or_create_by(name: name) }

# ジャンル
[ '和食', '洋食', '中華', 'エスニック', 'その他' ].each { |name| Category.find_or_create_by(name: name) }

# シーン
SCENE_NAMES.each { |name| Category.find_or_create_by(name: name) }

# 味覚/刺激
TASTE_NAMES.each { |name| Category.find_or_create_by(name: name) }

# スパイス/ハーブ
SPICE_NAMES.each { |name| Category.find_or_create_by(name: name) }

puts "Categories created!"

# 料理データの作成
puts "Creating dishes..."

foods_data = [
  # ガッツリ系 - 朝食
  { name: 'ベーコンエッグ', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'パンケーキ', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: '焼き魚', category: 'サッパリ', time_of_days: [ '朝', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'フレンチトースト', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'オムレツ', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ホットサンド', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ホットドッグ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },

  # ガッツリ系 - 昼食・夜食（定番）
  { name: 'カレーライス', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ 'その他' ] },
  { name: 'ラーメン', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '中華' ] },
  { name: 'とんかつ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'ハンバーグ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ステーキ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: '唐揚げ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: 'ピザ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: 'ハンバーガー', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: 'オムライス', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: '親子丼', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: '牛丼', category: 'ガッツリ', time_of_days: [ '朝', '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '焼きそば', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏', '秋' ], genres: [ '和食' ] },
  { name: 'お好み焼き', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'たこ焼き', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'かしみん焼き', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'エビフライ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'チキンカツ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'カツカレー', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'ロコモコ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'タコライス', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },

  # パスタ類
  { name: 'ミートソースパスタ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'カルボナーラ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ペペロンチーノ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'ナポリタン', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: 'たらこパスタ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'きのこパスタ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },

  # 中華料理
  { name: 'チャーハン', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '中華' ] },
  { name: '麻婆豆腐', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '中華' ] },
  { name: 'エビチリ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏', '秋' ], genres: [ '中華' ] },
  { name: '酢豚', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ '中華' ] },
  { name: '回鍋肉', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏', '秋' ], genres: [ '中華' ] },
  { name: '青椒肉絲', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ '中華' ] },
  { name: '餃子', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '中華' ] },
  { name: 'シュウマイ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '中華' ] },
  { name: '春巻き', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '中華' ] },
  { name: 'エビマヨ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '中華' ] },

  # 洋食（煮込み・オーブン料理）
  { name: 'グラタン', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'シチュー', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ドリア', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ラザニア', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ローストチキン', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ローストビーフ', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'チキンソテー', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋' ], genres: [ '洋食' ] },

  # 和食（定番）
  { name: '寿司', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: '刺身', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: '天ぷら', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },
  { name: 'すき焼き', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: 'しゃぶしゃぶ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '焼き鳥', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: 'うな重', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'かつ丼', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: '天丼', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },
  { name: '海鮮丼', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '鉄火丼', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'ちらし寿司', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春' ], genres: [ '和食' ] },
  { name: '手巻き寿司', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: 'おでん', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '肉じゃが', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '豚の角煮', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '鶏の照り焼き', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: '生姜焼き', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'チキン南蛮', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },
  { name: '山形風芋煮', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '宮城風芋煮', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '芋の子汁', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },

  # エスニック（メジャーなもの）
  { name: 'グリーンカレー', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'ガパオライス', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'パッタイ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'トムヤムクン', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'タンドリーチキン', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'バターチキンカレー', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ 'エスニック' ] },
  { name: 'キーマカレー', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏', '秋' ], genres: [ 'エスニック' ] },
  { name: 'ナン', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ 'エスニック' ] },
  { name: 'タコス', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'ブリトー', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'プルコギ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ 'エスニック' ] },
  { name: 'ビビンバ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ 'エスニック' ] },
  { name: 'チヂミ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ 'エスニック' ] },
  { name: 'フォー', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ 'エスニック' ] },

  # サッパリ系 - 朝食
  { name: 'おにぎり', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: 'トースト', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: '納豆ご飯', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: '卵かけご飯', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'フルーツヨーグルト', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'シリアル', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: 'オートミール', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'おかゆ', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: 'みそ汁', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: 'スムージー', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'フルーツサラダ', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },

  # サッパリ系 - 昼食・夜食
  { name: 'ざるそば', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'うどん', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: 'そうめん', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'ひやむぎ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '冷やし中華', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '中華' ] },
  { name: 'お茶漬け', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'サラダ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'シーザーサラダ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'コブサラダ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: '豆腐サラダ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: '海藻サラダ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },
  { name: 'ポテトサラダ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: '冷奴', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '湯豆腐', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '野菜炒め', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '中華' ] },
  { name: '水ナスの浅漬け', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '浅漬け', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '酢の物', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },

  # スープ類
  { name: 'コンソメスープ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ミネストローネ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'コーンスープ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'わかめスープ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },
  { name: '春雨スープ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏' ], genres: [ '中華' ] },
  { name: '卵スープ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '中華' ] },
  { name: 'クラムチャウダー', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },

  # その他サッパリ系
  { name: '茶碗蒸し', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'カプレーゼ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'カルパッチョ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'サンドイッチ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },

  # デザート
  { name: 'かき氷', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'スパイスコーラ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ 'その他' ] },
  { name: 'アイスクリーム', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'ミントアイス', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'フルーツサンド', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'プリン', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ゼリー', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'ハーブティー', category: 'サッパリ', time_of_days: [ '朝', '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ 'その他' ] },
  { name: 'チャイ', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ 'その他' ] },
  { name: 'スパイスクッキー', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] }
]

# 廃止した料理を明示的に削除
Dish.where(name: [ 'ミントゼリー' ]).destroy_all

foods_data.each do |food_data|
  dish = Dish.find_or_initialize_by(name: food_data[:name])
  dish.save!

  if dish.respond_to?(:image) && !dish.image.attached?
    svg = dish_placeholder_svg(dish.name)
    dish.image.attach(
      io: StringIO.new(svg),
      filename: "dish-#{dish.id}.svg",
      content_type: "image/svg+xml"
    )
  end

  label_values = {
    "気分" => Array(food_data[:category]),
    "時間帯" => food_data[:time_of_days],
    "季節" => food_data[:seasons],
    "ジャンル" => food_data[:genres],
    SCENE_LABEL => scene_names_for(food_data),
    TASTE_LABEL => taste_names_for(dish.name),
    SPICE_LABEL => spice_names_for(dish.name)
  }

  label_values.each do |label, names|
    sync_label_tags(dish: dish, label: label, names: names)
  end
end

puts "Dishes created!"
puts "Total dishes: #{Dish.count}"
puts "Total categories: #{Category.count}"
puts "Total connections: #{CategoryContent.count}"
SeedRun.create!(version: SEED_VERSION, applied_at: Time.current)
puts "Seed version #{SEED_VERSION} recorded."
puts "Seed data creation completed!"
