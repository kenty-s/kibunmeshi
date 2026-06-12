class CleanupDuplicateCategoryRecords < ActiveRecord::Migration[7.2]
  class Category < ApplicationRecord
    self.table_name = "categories"
  end

  def up
    return unless table_exists?(:categories) && table_exists?(:category_contents)

    Category.reset_column_information

    deduplicate_categories_by_name
    deduplicate_category_contents
    add_uniqueness_guards
  end

  def down
    remove_index :category_contents, name: "index_category_contents_unique_normalized_label" if index_name_exists?(:category_contents, "index_category_contents_unique_normalized_label")
    remove_index :categories, name: "index_categories_on_name_unique" if index_name_exists?(:categories, "index_categories_on_name_unique")
  end

  private

  def deduplicate_categories_by_name
    Category.where.not(name: [ nil, "" ])
            .group(:name)
            .having("COUNT(*) > 1")
            .pluck(:name)
            .each do |name|
      ids = Category.where(name: name).order(:id).pluck(:id)
      canonical_id = ids.first
      duplicate_ids = ids.drop(1)
      next if duplicate_ids.empty?

      execute <<~SQL.squish
        UPDATE category_contents
           SET category_id = #{canonical_id}
         WHERE category_id IN (#{duplicate_ids.join(",")})
      SQL

      Category.where(id: duplicate_ids).delete_all
    end
  end

  def deduplicate_category_contents
    execute <<~SQL.squish
      DELETE FROM category_contents duplicate_rows
      USING category_contents kept_rows
      WHERE duplicate_rows.id > kept_rows.id
        AND duplicate_rows.dish_id = kept_rows.dish_id
        AND duplicate_rows.category_id = kept_rows.category_id
        AND COALESCE(duplicate_rows.label, '') = COALESCE(kept_rows.label, '')
    SQL
  end

  def add_uniqueness_guards
    add_index :categories,
              :name,
              unique: true,
              where: "name IS NOT NULL",
              name: "index_categories_on_name_unique",
              if_not_exists: true

    add_index :category_contents,
              "dish_id, category_id, COALESCE(label, '')",
              unique: true,
              name: "index_category_contents_unique_normalized_label",
              if_not_exists: true
  end
end
