class UpdateChirashiSushiSceneToHomeOnly < ActiveRecord::Migration[7.2]
  class Dish < ApplicationRecord
    self.table_name = "dishes"
  end

  class Category < ApplicationRecord
    self.table_name = "categories"
  end

  class CategoryContent < ApplicationRecord
    self.table_name = "category_contents"
  end

  SCENE_LABEL = "シーン".freeze
  TARGET_DISH_NAME = "ちらし寿司".freeze
  HOME_SCENE_NAME = "内食".freeze

  def up
    return unless table_exists?(:dishes) && table_exists?(:categories) && table_exists?(:category_contents)

    dish = Dish.find_by(name: TARGET_DISH_NAME)
    return unless dish

    home_scene = Category.find_or_create_by!(name: HOME_SCENE_NAME)

    CategoryContent.where(dish_id: dish.id, label: SCENE_LABEL).delete_all
    CategoryContent.find_or_create_by!(dish_id: dish.id, category_id: home_scene.id, label: SCENE_LABEL)
  end

  def down
    # no-op: data correction migration
  end
end
