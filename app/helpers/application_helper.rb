module ApplicationHelper
  SPICE_ICON_MAP = {
    "ブラックペッパー" => "black_pepper.png",
    "ホワイトペッパー" => "white_pepper.webp",
    "ガーリック" => "garlic.png",
    "生姜" => "ginger.png",
    "唐辛子" => "chili.png",
    "クミン" => "cumin.png",
    "コリアンダー" => "coriander.png",
    "ターメリック" => "turmeric.png",
    "パプリカ" => "paprika.png",
    "オレガノ" => "oregano.png",
    "ローズマリー" => "rosemary.png",
    "ミント" => "mint.png",
    "パセリ" => "parsley.png",
    "ローレル" => "laurel.png",
    "ナツメグ" => "nutmeg.png",
    "クローブ" => "clove.png",
    "山椒" => "sansho.png",
    "わさび" => "wasabi.png",
    "からし" => "karashi.png",
    "マスタード" => "mustard.png",
    "カルダモン" => "cardamom.png",
    "シナモン" => "cinnamon.png",
    "バジル" => "basil.png",
    "五香粉" => "gokohfun.png"
  }.freeze

  def spice_icon_path(spice_name)
    SPICE_ICON_MAP[spice_name.to_s]
  end
end
