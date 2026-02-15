require "cgi"
require "stringio"
require "zlib"

SEED_VERSION = "2026-02-15-spice-pairing-plausible-v8"

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
SPICE_NAMES = [
  "ブラックペッパー", "ガーリック", "生姜", "唐辛子", "クミン", "コリアンダー", "ターメリック", "パプリカ",
  "オレガノ", "ローズマリー", "タイム", "パセリ", "ローレル", "ナツメグ", "クローブ", "山椒",
  "わさび", "からし", "マスタード", "カルダモン", "シナモン", "バジル", "五香粉", "ホワイトペッパー"
].freeze

def spices_for_dish(name)
  spices =
    case name
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

# カテゴリを作成（全てのタグをCategoryとして統合）
puts "Creating categories..."

# 旧表記を統一して重複カテゴリを防ぐ
legacy_pepper = Category.find_by(name: "黒胡椒")
current_pepper = Category.find_by(name: "ブラックペッパー")
if legacy_pepper
  if current_pepper
    CategoryContent.where(category_id: legacy_pepper.id).update_all(category_id: current_pepper.id)
    legacy_pepper.destroy!
  else
    legacy_pepper.update!(name: "ブラックペッパー")
  end
end

dill = Category.find_by(name: "ディル")
white_pepper = Category.find_or_create_by(name: "ホワイトペッパー")
if dill && dill.id != white_pepper.id
  CategoryContent.where(category_id: dill.id).update_all(category_id: white_pepper.id)
  dill.destroy!
end

# 気分（MVP用：ガッツリ/サッパリ）
[ 'ガッツリ', 'サッパリ' ].each { |name| Category.find_or_create_by(name: name) }

# 時間帯
[ '朝', '昼', '夜' ].each { |name| Category.find_or_create_by(name: name) }

# 季節
[ '春', '夏', '秋', '冬' ].each { |name| Category.find_or_create_by(name: name) }

# 気分詳細
[ '疲れた', '元気', 'リラックス', '集中したい', '特別な日' ].each { |name| Category.find_or_create_by(name: name) }

# ジャンル
[ '和食', '洋食', '中華', 'エスニック', 'その他' ].each { |name| Category.find_or_create_by(name: name) }

# 調理スタイル
[ '簡単', '本格的', '温かい', '冷たい' ].each { |name| Category.find_or_create_by(name: name) }

# ヘルシーさ
[ 'ヘルシー', 'こってり', '野菜多め', 'タンパク質重視' ].each { |name| Category.find_or_create_by(name: name) }

# スパイス/ハーブ
SPICE_NAMES.each { |name| Category.find_or_create_by(name: name) }

puts "Categories created!"

# 料理データの作成
puts "Creating dishes..."

foods_data = [
  # ガッツリ系 - 朝食
  { name: 'ベーコンエッグ', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり', 'タンパク質重視' ] },
  { name: 'パンケーキ', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], moods: [ '特別な日', 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: '焼き魚', category: 'ガッツリ', time_of_days: [ '朝', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '集中したい' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: 'フレンチトースト', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '春', '秋', '冬' ], moods: [ '特別な日' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'オムレツ', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: 'ホットサンド', category: 'ガッツリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'ホットドッグ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },

  # ガッツリ系 - 昼食・夜食（定番）
  { name: 'カレーライス', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], moods: [ '元気', '疲れた' ], genres: [ 'その他' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: 'ラーメン', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ '疲れた', '元気' ], genres: [ '中華' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'とんかつ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気', '疲れた' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり', 'タンパク質重視' ] },
  { name: 'ハンバーグ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり', 'タンパク質重視' ] },
  { name: 'ステーキ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '特別な日' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: '唐揚げ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり', 'タンパク質重視' ] },
  { name: 'ピザ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], moods: [ '元気', '特別な日' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'ハンバーガー', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'オムライス', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気', 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: '親子丼', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '疲れた', 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: '牛丼', category: 'ガッツリ', time_of_days: [ '朝', '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ '疲れた', '元気' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり', 'タンパク質重視' ] },
  { name: '焼きそば', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏', '秋' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'お好み焼き', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'たこ焼き', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'かしみん焼き', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり', 'タンパク質重視' ] },
  { name: 'エビフライ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], moods: [ '特別な日' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'チキンカツ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり', 'タンパク質重視' ] },
  { name: 'カツカレー', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'ロコモコ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり', 'タンパク質重視' ] },
  { name: 'タコライス', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ '野菜多め' ] },

  # パスタ類
  { name: 'ミートソースパスタ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'カルボナーラ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'ペペロンチーノ', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '春', '夏' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'ナポリタン', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'たらこパスタ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'きのこパスタ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー' ] },

  # 中華料理
  { name: 'チャーハン', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: '麻婆豆腐', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'エビチリ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏', '秋' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: '酢豚', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: '回鍋肉', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏', '秋' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: '青椒肉絲', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: '餃子', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: 'シュウマイ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: '春巻き', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'エビマヨ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], moods: [ '元気' ], genres: [ '中華' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },

  # 洋食（煮込み・オーブン料理）
  { name: 'グラタン', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'シチュー', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: 'ドリア', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'ラザニア', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ '特別な日' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'ローストチキン', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ '特別な日' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: 'ローストビーフ', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ '特別な日' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: 'チキンソテー', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },

  # 和食（定番）
  { name: '寿司', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '本格的' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: '刺身', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '春', '夏', '秋' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: '天ぷら', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'すき焼き', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'しゃぶしゃぶ', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: '焼き鳥', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '春', '夏', '秋' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: 'うな重', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: 'かつ丼', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: '天丼', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: '海鮮丼', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: '鉄火丼', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: 'ちらし寿司', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '本格的' ], healthiness_types: [ 'ヘルシー' ] },
  { name: '手巻き寿司', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], moods: [ '特別な日' ], genres: [ '和食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'おでん', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: '肉じゃが', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: '豚の角煮', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: '鶏の照り焼き', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: '生姜焼き', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: 'チキン南蛮', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], moods: [ '元気' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: '山形風芋煮', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ '特別な日', 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: '宮城風芋煮', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め', 'こってり' ] },
  { name: '芋の子汁', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー', '野菜多め' ] },

  # エスニック（メジャーなもの）
  { name: 'グリーンカレー', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: 'ガパオライス', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: 'パッタイ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'トムヤムクン', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'タンドリーチキン', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: 'バターチキンカレー', category: 'ガッツリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'キーマカレー', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏', '秋' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: 'ナン', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'タコス', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '簡単' ], healthiness_types: [ '野菜多め' ] },
  { name: 'ブリトー', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '簡単' ], healthiness_types: [ '野菜多め' ] },
  { name: 'プルコギ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'タンパク質重視' ] },
  { name: 'ビビンバ', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋', '冬' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ '野菜多め' ] },
  { name: 'チヂミ', category: 'ガッツリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], moods: [ '元気' ], genres: [ 'エスニック' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'こってり' ] },
  { name: 'フォー', category: 'ガッツリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ 'エスニック' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー' ] },

  # サッパリ系 - 朝食
  { name: 'おにぎり', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋' ], moods: [ '集中したい' ], genres: [ '和食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'トースト', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: '納豆ご飯', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋', '冬' ], moods: [ '集中したい' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: '卵かけご飯', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '秋', '冬' ], moods: [ '集中したい' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: 'フルーツヨーグルト', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'シリアル', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏', '秋' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'オートミール', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], moods: [ '集中したい' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'おかゆ', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], moods: [ '疲れた', 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'みそ汁', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'スムージー', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー', '野菜多め' ] },
  { name: 'フルーツサラダ', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '春', '夏' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },

  # サッパリ系 - 昼食・夜食
  { name: 'ざるそば', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'うどん', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ '疲れた' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'そうめん', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'ひやむぎ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: '冷やし中華', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '中華' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'お茶漬け', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ '疲れた', 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'サラダ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], moods: [ '集中したい' ], genres: [ '洋食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー', '野菜多め' ] },
  { name: 'シーザーサラダ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], moods: [ '集中したい' ], genres: [ '洋食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー', '野菜多め' ] },
  { name: 'コブサラダ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], moods: [ '元気' ], genres: [ '洋食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー', '野菜多め', 'タンパク質重視' ] },
  { name: '豆腐サラダ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: '海藻サラダ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー', '野菜多め' ] },
  { name: 'ポテトサラダ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏', '秋' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'こってり' ] },
  { name: '冷奴', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: '湯豆腐', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: '野菜炒め', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏', '秋' ], moods: [ '集中したい' ], genres: [ '中華' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー', '野菜多め' ] },
  { name: '水ナスの浅漬け', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー', '野菜多め' ] },
  { name: '浅漬け', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: '酢の物', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },

  # スープ類
  { name: 'コンソメスープ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'ミネストローネ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー', '野菜多め' ] },
  { name: 'コーンスープ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'わかめスープ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: '春雨スープ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '夏' ], moods: [ 'リラックス' ], genres: [ '中華' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: '卵スープ', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '中華' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'クラムチャウダー', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー' ] },

  # その他サッパリ系
  { name: '茶碗蒸し', category: 'サッパリ', time_of_days: [ '夜' ], seasons: [ '春', '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '本格的', '温かい' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: 'カプレーゼ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'カルパッチョ', category: 'サッパリ', time_of_days: [ '昼', '夜' ], seasons: [ '春', '夏' ], moods: [ '特別な日', 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー', 'タンパク質重視' ] },
  { name: 'サンドイッチ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋' ], moods: [ '集中したい' ], genres: [ '洋食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー' ] },

  # デザート
  { name: 'かき氷', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '和食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'スパイスコーラ', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ 'その他' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ], spices: [ 'シナモン', '生姜', 'ナツメグ' ] },
  { name: 'アイスクリーム', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'フルーツサンド', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'プリン', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '春', '夏', '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '本格的', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'ゼリー', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '夏' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単', '冷たい' ], healthiness_types: [ 'ヘルシー' ] },
  { name: 'チャイ', category: 'サッパリ', time_of_days: [ '朝' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ 'その他' ], cooking_styles: [ '簡単', '温かい' ], healthiness_types: [ 'ヘルシー' ], spices: [ 'シナモン', '生姜', 'ブラックペッパー' ] },
  { name: 'スパイスクッキー', category: 'サッパリ', time_of_days: [ '昼' ], seasons: [ '秋', '冬' ], moods: [ 'リラックス' ], genres: [ '洋食' ], cooking_styles: [ '簡単' ], healthiness_types: [ 'ヘルシー' ], spices: [ 'シナモン', 'ナツメグ', '生姜' ] }
]

foods_data.each do |food_data|
  dish = Dish.find_or_initialize_by(name: food_data[:name])
  dish.assign_attributes(
    time_of_days:      food_data[:time_of_days],
    seasons:           food_data[:seasons],
    moods:             food_data[:moods],
    genres:            food_data[:genres],
    cooking_styles:    food_data[:cooking_styles],
    healthiness_types: food_data[:healthiness_types]
  )
  dish.save!

  if dish.respond_to?(:image) && !dish.image.attached?
    svg = dish_placeholder_svg(dish.name)
    dish.image.attach(
      io: StringIO.new(svg),
      filename: "dish-#{dish.id}.svg",
      content_type: "image/svg+xml"
    )
  end

  # 気分カテゴリ（ガッツリ/サッパリ）
  if food_data[:category]
    category = Category.find_by(name: food_data[:category])
    CategoryContent.find_or_create_by(dish: dish, category: category, label: "気分") if category
  end

  # 時間帯
  food_data[:time_of_days]&.each do |time_name|
    category = Category.find_by(name: time_name)
    CategoryContent.find_or_create_by(dish: dish, category: category, label: "時間帯") if category
  end

  # 季節
  food_data[:seasons]&.each do |season_name|
    category = Category.find_by(name: season_name)
    CategoryContent.find_or_create_by(dish: dish, category: category, label: "季節") if category
  end

  # 気分詳細
  food_data[:moods]&.each do |mood_name|
    category = Category.find_by(name: mood_name)
    CategoryContent.find_or_create_by(dish: dish, category: category, label: "気分詳細") if category
  end

  # ジャンル
  food_data[:genres]&.each do |genre_name|
    category = Category.find_by(name: genre_name)
    CategoryContent.find_or_create_by(dish: dish, category: category, label: "ジャンル") if category
  end

  # 調理スタイル
  food_data[:cooking_styles]&.each do |style_name|
    category = Category.find_by(name: style_name)
    CategoryContent.find_or_create_by(dish: dish, category: category, label: "調理スタイル") if category
  end

  # ヘルシーさ
  food_data[:healthiness_types]&.each do |health_name|
    category = Category.find_by(name: health_name)
    CategoryContent.find_or_create_by(dish: dish, category: category, label: "ヘルシーさ") if category
  end

  spice_names = Array(food_data[:spices]).presence || spices_for_dish(dish.name)
  CategoryContent.where(dish: dish, label: SPICE_LABEL).delete_all
  spice_names.each do |spice_name|
    category = Category.find_by(name: spice_name)
    CategoryContent.find_or_create_by(dish: dish, category: category, label: SPICE_LABEL) if category
  end
end

puts "Dishes created!"
puts "Total dishes: #{Dish.count}"
puts "Total categories: #{Category.count}"
puts "Total connections: #{CategoryContent.count}"
SeedRun.create!(version: SEED_VERSION, applied_at: Time.current)
puts "Seed version #{SEED_VERSION} recorded."
puts "Seed data creation completed!"
