class ReplaceDillWithWhitePepper < ActiveRecord::Migration[7.2]
  class Category < ApplicationRecord
    self.table_name = "categories"
  end

  class CategoryContent < ApplicationRecord
    self.table_name = "category_contents"
  end

  def up
    return unless table_exists?(:categories) && table_exists?(:category_contents)

    dill = Category.find_by(name: "ディル")
    return unless dill

    white_pepper = Category.find_or_create_by!(name: "ホワイトペッパー")

    CategoryContent.where(category_id: dill.id).find_each do |content|
      CategoryContent.find_or_create_by!(
        dish_id: content.dish_id,
        category_id: white_pepper.id,
        label: content.label
      )
    end

    CategoryContent.where(category_id: dill.id).delete_all
    dill.destroy! if CategoryContent.where(category_id: dill.id).none?
  end

  def down
    # no-op: forward-only cleanup migration
  end
end
