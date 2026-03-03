class RemoveUnusedSearchFieldsFromDishes < ActiveRecord::Migration[7.2]
  def change
    remove_column :dishes, :moods, :jsonb if column_exists?(:dishes, :moods)
    remove_column :dishes, :cooking_styles, :jsonb if column_exists?(:dishes, :cooking_styles)
    remove_column :dishes, :healthiness_types, :jsonb if column_exists?(:dishes, :healthiness_types)
  end
end
