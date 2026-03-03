class UnifyDishConditionTagsToCategoryContents < ActiveRecord::Migration[7.2]
  class Dish < ApplicationRecord
    self.table_name = "dishes"
  end

  class Category < ApplicationRecord
    self.table_name = "categories"
  end

  class CategoryContent < ApplicationRecord
    self.table_name = "category_contents"
  end

  COLUMN_LABEL_MAP = {
    time_of_days: "時間帯",
    seasons: "季節",
    genres: "ジャンル"
  }.freeze

  def up
    return unless table_exists?(:dishes) && table_exists?(:categories) && table_exists?(:category_contents)

    Dish.reset_column_information
    backfill_category_contents_from_dish_columns

    COLUMN_LABEL_MAP.each_key do |column|
      remove_column :dishes, column, :jsonb if column_exists?(:dishes, column)
    end
  end

  def down
    return unless table_exists?(:dishes) && table_exists?(:categories) && table_exists?(:category_contents)

    add_column :dishes, :time_of_days, :jsonb unless column_exists?(:dishes, :time_of_days)
    add_column :dishes, :seasons, :jsonb unless column_exists?(:dishes, :seasons)
    add_column :dishes, :genres, :jsonb unless column_exists?(:dishes, :genres)

    Dish.reset_column_information
    backfill_dish_columns_from_category_contents
  end

  private

  def backfill_category_contents_from_dish_columns
    Dish.find_each do |dish|
      COLUMN_LABEL_MAP.each do |column, label|
        next unless Dish.column_names.include?(column.to_s)

        names = Array(dish.public_send(column)).map(&:to_s).reject(&:blank?).uniq
        names.each do |name|
          category = Category.find_or_create_by!(name: name)
          CategoryContent.find_or_create_by!(
            dish_id: dish.id,
            category_id: category.id,
            label: label
          )
        end
      end
    end
  end

  def backfill_dish_columns_from_category_contents
    Dish.find_each do |dish|
      updates = {}

      COLUMN_LABEL_MAP.each do |column, label|
        names = CategoryContent
          .joins("INNER JOIN categories ON categories.id = category_contents.category_id")
          .where(dish_id: dish.id, label: label)
          .pluck("categories.name")
          .map(&:to_s)
          .reject(&:blank?)
          .uniq
        updates[column] = names
      end

      dish.update_columns(updates) if updates.present?
    end
  end
end
