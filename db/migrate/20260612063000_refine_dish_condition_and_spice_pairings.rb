class RefineDishConditionAndSpicePairings < ActiveRecord::Migration[7.2]
  class Dish < ApplicationRecord
    self.table_name = "dishes"
  end

  class Category < ApplicationRecord
    self.table_name = "categories"
  end

  class CategoryContent < ApplicationRecord
    self.table_name = "category_contents"
  end

  TIME_LABEL = "時間帯"
  SPICE_LABEL = "スパイス・ハーブ"

  SPICE_FIXES = {
    "たらこパスタ" => [ "ブラックペッパー", "パセリ" ],
    "きのこパスタ" => [ "ブラックペッパー", "ガーリック", "パセリ" ],
    "フルーツサラダ" => [ "ミント" ],
    "カプレーゼ" => [ "バジル", "ブラックペッパー" ],
    "アイスクリーム" => [ "シナモン" ],
    "フルーツサンド" => [ "シナモン" ],
    "カルパッチョ" => [ "ブラックペッパー", "パセリ" ]
  }.freeze

  TIME_FIXES = {
    "チヂミ" => [ "昼", "夜" ]
  }.freeze

  def up
    return unless table_exists?(:dishes) && table_exists?(:categories) && table_exists?(:category_contents)

    reset_models

    SPICE_FIXES.each do |dish_name, spice_names|
      sync_label_tags(dish_name: dish_name, label: SPICE_LABEL, names: spice_names)
    end

    TIME_FIXES.each do |dish_name, time_names|
      sync_label_tags(dish_name: dish_name, label: TIME_LABEL, names: time_names)
    end
  end

  def down
    # no-op: data correction
  end

  private

  def reset_models
    Dish.reset_column_information
    Category.reset_column_information
    CategoryContent.reset_column_information
  end

  def sync_label_tags(dish_name:, label:, names:)
    dish = Dish.find_by(name: dish_name)
    return unless dish

    CategoryContent.where(dish_id: dish.id, label: label).delete_all

    Array(names).each do |name|
      category = Category.find_or_create_by!(name: name)
      CategoryContent.find_or_create_by!(dish_id: dish.id, category_id: category.id, label: label)
    end
  end
end
