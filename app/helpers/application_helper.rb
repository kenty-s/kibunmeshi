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

  def analytics_change_badge_class(change)
    case analytics_change_direction(change)
    when :up
      "border-emerald-200 bg-emerald-50 text-emerald-700"
    when :down
      "border-rose-200 bg-rose-50 text-rose-700"
    else
      "border-gray-200 bg-gray-50 text-gray-600"
    end
  end

  def analytics_change_text(change, label:, unit:)
    return "#{label}: 比較データなし" if change.blank?

    "#{label}: #{analytics_change_arrow(change)} #{analytics_change_delta_text(change, unit: unit)} (#{analytics_change_percent_text(change)})"
  end

  def analytics_change_arrow(change)
    case analytics_change_direction(change)
    when :up
      "↑"
    when :down
      "↓"
    else
      "→"
    end
  end

  def analytics_change_delta_text(change, unit:)
    return "比較データなし" if change.blank?

    delta = change[:change].to_i
    signed_delta = delta.positive? ? "+#{number_with_delimiter(delta)}" : number_with_delimiter(delta)
    "#{signed_delta}#{unit}"
  end

  def analytics_change_percent_text(change)
    return "比較データなし" if change.blank?

    if change[:percent].nil?
      change[:current].positive? ? "新規" : "変化なし"
    else
      signed_percent = change[:percent].positive? ? "+#{change[:percent]}" : change[:percent].to_s
      "#{signed_percent}%"
    end
  end

  def analytics_change_direction(change)
    return :flat if change.blank? || change[:change].zero?

    change[:change].positive? ? :up : :down
  end
end
