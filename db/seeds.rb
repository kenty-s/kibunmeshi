require "cgi"
require "stringio"
require "zlib"

SEED_VERSION = "2026-03-05-scene-rule-unified-v1"

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

SPICE_LABEL = "スパイス・ハーブ"
SPICE_NAMES = Dish.spice_pairings.values.flatten.uniq.freeze
TASTE_LABEL = "味覚・刺激"
TASTE_NAMES = [ "甘い", "すっぱい", "しょっぱい", "苦い", "辛い" ].freeze
SCENE_LABEL = "シーン"
SCENE_NAMES = [ "外食", "弁当", "内食" ].freeze
REMOVED_LABELS = [ "気分詳細", "調理スタイル", "ヘルシーさ" ].freeze
REMOVED_CATEGORY_NAMES = [
  "疲れた", "元気", "リラックス", "集中したい", "特別な日",
  "簡単", "本格的", "温かい", "冷たい",
  "ヘルシー", "こってり", "野菜多め", "タンパク質重視"
].freeze

NO_BENTO_PATTERN = /ラーメン|うどん|そうめん|ひやむぎ|ざるそば|冷やし中華|パスタ|フォー|スープ|みそ汁|おでん|すき焼き|しゃぶしゃぶ|刺身|寿司|海鮮丼|鉄火丼|ちらし寿司|手巻き寿司|かき氷|アイス|ゼリー|プリン|スムージー|ハーブティー|チャイ|スパイスコーラ/
BENTO_FRIENDLY_PATTERN = /生姜焼き|唐揚げ|ハンバーグ|オムライス|焼きそば|チャーハン|チキンカツ|鶏の照り焼き|野菜炒め|春巻き|エビフライ|チキン南蛮|ホットドッグ|サンドイッチ|おにぎり|タコライス/
HOME_STYLE_PATTERN = /みそ汁|おかゆ|納豆ご飯|卵かけご飯|肉じゃが|野菜炒め|焼き魚|湯豆腐|冷奴|おでん|茶碗蒸し|浅漬け|酢の物|芋煮|芋の子汁|わかめスープ|卵スープ|コンソメスープ|コーンスープ|春雨スープ|ミネストローネ|クラムチャウダー|シリアル|トースト|ホットサンド|オムレツ|フルーツヨーグルト|オートミール|サラダ|豆腐サラダ|海藻サラダ|ポテトサラダ|フルーツサラダ|おにぎり|お茶漬け|スムージー|ハーブティー|チャイ/
EATING_OUT_PATTERN = /寿司|刺身|天ぷら|すき焼き|しゃぶしゃぶ|焼き鳥|うな重|ラーメン|ピザ|ハンバーガー|ステーキ|グラタン|ドリア|ラザニア|ローストチキン|ローストビーフ|エビチリ|麻婆豆腐|トムヤムクン|ナン|タンドリー|ガパオ|パッタイ|ビビンバ|チヂミ|プルコギ|タコス|ブリトー|カルパッチョ|カプレーゼ/
HOME_ONLY_PATTERN = /みそ汁|おかゆ|納豆ご飯|卵かけご飯|スムージー|ハーブティー|チャイ|ちらし寿司/

def scene_names_for(food_data)
  name = food_data[:name].to_s

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
    condition = Category.find_by(name: name)
    CategoryContent.find_or_create_by(dish: dish, category: condition, label: label) if condition
  end
end

# 検索条件の選択肢をCategoryとして作成する。
# 例: "ガッツリ", "昼", "夏", "和食" など。
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

# 味覚・刺激
TASTE_NAMES.each { |name| Category.find_or_create_by(name: name) }

# スパイス・ハーブ
SPICE_NAMES.each { |name| Category.find_or_create_by(name: name) }

puts "Categories created!"

# 料理データの作成
puts "Creating dishes..."

foods_data = [
  # ガッツリ系
  # 朝食
  { name: 'ベーコンエッグ', mood: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'パンケーキ', mood: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'フレンチトースト', mood: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'オムレツ', mood: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ホットサンド', mood: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },

  # 昼食・夜食（定番）
  { name: 'カレーライス', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ 'その他' ] },
  { name: 'ラーメン', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '中華' ] },
  { name: 'とんかつ', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'ハンバーグ', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ステーキ', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: '唐揚げ', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: 'ピザ', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: 'ハンバーガー', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: 'オムライス', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: '親子丼', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: '牛丼', mood: 'ガッツリ', time_of_days: [ '朝', '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '焼きそば', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏', '秋' ], genres: [ '和食' ] },
  { name: 'お好み焼き', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'たこ焼き', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'かしみん焼き', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'エビフライ', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'チキンカツ', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'カツカレー', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'ロコモコ', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'タコライス', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'ホットドッグ', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },

  # パスタ類
  { name: 'ミートソースパスタ', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'カルボナーラ', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ナポリタン', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: 'たらこパスタ', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '洋食' ] },

  # 中華料理
  { name: 'チャーハン', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '中華' ] },
  { name: '麻婆豆腐', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '中華' ] },
  { name: 'エビチリ', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏', '秋' ], genres: [ '中華' ] },
  { name: '酢豚', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ '中華' ] },
  { name: '回鍋肉', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏', '秋' ], genres: [ '中華' ] },
  { name: '青椒肉絲', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ '中華' ] },
  { name: '餃子', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '中華' ] },
  { name: 'シュウマイ', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '中華' ] },
  { name: '春巻き', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '中華' ] },
  { name: 'エビマヨ', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '中華' ] },

  # 洋食（煮込み・オーブン料理）
  { name: 'グラタン', mood: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ドリア', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ラザニア', mood: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ローストチキン', mood: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ローストビーフ', mood: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'チキンソテー', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋' ], genres: [ '洋食' ] },

  # 和食（定番）
  { name: '天ぷら', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },
  { name: 'すき焼き', mood: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '焼き鳥', mood: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: 'うな重', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'かつ丼', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: '天丼', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },
  { name: '豚の角煮', mood: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '鶏の照り焼き', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: '生姜焼き', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'チキン南蛮', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },

  # エスニック（メジャーなもの）
  { name: 'ガパオライス', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'タンドリーチキン', mood: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'バターチキンカレー', mood: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ 'エスニック' ] },
  { name: 'キーマカレー', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏', '秋' ], genres: [ 'エスニック' ] },
  { name: 'ナン', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ 'エスニック' ] },
  { name: 'タコス', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'ブリトー', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'プルコギ', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ 'エスニック' ] },
  { name: 'ビビンバ', mood: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ 'エスニック' ] },
  { name: 'チヂミ', mood: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ 'エスニック' ] },

  # サッパリ系
  # 朝食
  { name: 'おにぎり', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: 'トースト', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: '納豆ご飯', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: '卵かけご飯', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'フルーツヨーグルト', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'シリアル', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: 'オートミール', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'おかゆ', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: 'みそ汁', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: 'スムージー', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'フルーツサラダ', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: '焼き魚', mood: 'サッパリ', time_of_days: [ '朝', '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },

  # 昼食・夜食（定番）
  { name: 'ざるそば', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'うどん', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: 'そうめん', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'ひやむぎ', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '冷やし中華', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '中華' ] },
  { name: 'お茶漬け', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: '寿司', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '和食' ] },
  { name: '刺身', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: 'しゃぶしゃぶ', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '海鮮丼', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '鉄火丼', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'ちらし寿司', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春' ], genres: [ '和食' ] },
  { name: '手巻き寿司', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: 'おでん', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '肉じゃが', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '山形風芋煮', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '宮城風芋煮', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '芋の子汁', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },

  # パスタ類
  { name: 'ペペロンチーノ', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'きのこパスタ', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },

  # サラダ・副菜
  { name: 'サラダ', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'シーザーサラダ', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'コブサラダ', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: '豆腐サラダ', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '和食' ] },
  { name: '海藻サラダ', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },
  { name: 'ポテトサラダ', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },
  { name: '冷奴', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '湯豆腐', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '和食' ] },
  { name: '野菜炒め', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏', '秋' ], genres: [ '中華' ] },
  { name: '水ナスの浅漬け', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '浅漬け', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: '酢の物', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '夏' ], genres: [ '和食' ] },

  # 洋食（煮込み・オーブン料理）
  { name: 'シチュー', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },

  # エスニック（メジャーなもの）
  { name: 'グリーンカレー', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'パッタイ', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'トムヤムクン', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], genres: [ 'エスニック' ] },
  { name: 'フォー', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ 'エスニック' ] },

  # スープ類
  { name: 'コンソメスープ', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ミネストローネ', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'コーンスープ', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'わかめスープ', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏' ], genres: [ '和食' ] },
  { name: '春雨スープ', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏' ], genres: [ '中華' ] },
  { name: '卵スープ', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '中華' ] },
  { name: 'クラムチャウダー', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] },

  # その他サッパリ系
  { name: '茶碗蒸し', mood: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '秋', '冬' ], genres: [ '和食' ] },
  { name: 'カプレーゼ', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'カルパッチョ', mood: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'サンドイッチ', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], genres: [ '洋食' ] },

  # デザート
  { name: 'かき氷', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '和食' ] },
  { name: 'スパイスコーラ', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ 'その他' ] },
  { name: 'アイスクリーム', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'ミントアイス', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'フルーツサンド', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], genres: [ '洋食' ] },
  { name: 'プリン', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ '洋食' ] },
  { name: 'ゼリー', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], genres: [ '洋食' ] },
  { name: 'ハーブティー', mood: 'サッパリ', time_of_days: [ '朝', '昼' ], seasons: [ '春', '夏', '秋', '冬' ], genres: [ 'その他' ] },
  { name: 'チャイ', mood: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], genres: [ 'その他' ] },
  { name: 'スパイスクッキー', mood: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '秋', '冬' ], genres: [ '洋食' ] }
]

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

  condition_labels = {
    "気分" => Array(food_data[:mood]),
    "時間帯" => food_data[:time_of_days],
    "季節" => food_data[:seasons],
    "ジャンル" => food_data[:genres],
    SCENE_LABEL => scene_names_for(food_data),
    TASTE_LABEL => taste_names_for(dish.name),
    SPICE_LABEL => spice_names_for(dish.name)
  }

  condition_labels.each do |label, names|
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
