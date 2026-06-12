require 'rails_helper'
require 'securerandom'

RSpec.describe Dish, type: :model do
  describe '.by_category' do
    it 'returns dishes that belong to the given category name' do
      washoku = FactoryBot.create(:category)
      dish_in_category = FactoryBot.create(:dish)
      FactoryBot.create(:category_content, dish: dish_in_category, category: washoku)

      yoshoku = FactoryBot.create(:category)
      other_dish = FactoryBot.create(:dish)
      FactoryBot.create(:category_content, dish: other_dish, category: yoshoku)

      expect(Dish.by_category(washoku.name)).to contain_exactly(dish_in_category)
    end
  end

  describe '.scene_names_for' do
    it 'treats chirashi sushi as home-oriented' do
      expect(Dish.scene_names_for('ちらし寿司')).to eq([ '内食' ])
    end
  end

  describe '.search_by_conditions' do
    let!(:keyword) { "spec-keyword-#{SecureRandom.hex(4)}" }
    let!(:main_category) { FactoryBot.create(:category) }
    let!(:spice_category_name) { "spec-spice-#{SecureRandom.hex(4)}" }
    let!(:spice_category) { FactoryBot.create(:category, name: spice_category_name) }
    let!(:taste_category_name) { "辛い" }
    let!(:taste_category) { Category.find_or_create_by!(name: taste_category_name) }
    let!(:morning_category) { Category.find_or_create_by!(name: "朝") }
    let!(:night_category) { Category.find_or_create_by!(name: "夜") }

    let!(:matched_dish) do
      dish = FactoryBot.create(:dish, name: "#{keyword}-料理A")
      FactoryBot.create(:category_content, dish: dish, category: main_category)
      FactoryBot.create(:category_content, dish: dish, category: spice_category)
      FactoryBot.create(:category_content, dish: dish, category: taste_category, label: Dish::TASTE_LABEL)
      FactoryBot.create(:category_content, dish: dish, category: morning_category, label: Dish::TIME_LABEL)
      dish
    end

    let!(:other_dish) do
      dish = FactoryBot.create(:dish, name: '料理B')
      FactoryBot.create(:category_content, dish: dish, category: FactoryBot.create(:category))
      FactoryBot.create(:category_content, dish: dish, category: night_category, label: Dish::TIME_LABEL)
      dish
    end

    it 'combines multiple filters' do
      other_dish
      result = Dish.search_by_conditions(
        keyword: keyword,
        category: main_category.name,
        time_of_day: '朝',
        spice_name: spice_category_name,
        taste: taste_category_name
      )
      expect(result).to contain_exactly(matched_dish)
    end

    it 'returns no dishes when requested taste tags are missing' do
      CategoryContent.where(label: Dish::TASTE_LABEL).delete_all
      result = Dish.search_by_conditions(taste: '辛い')
      expect(result).to be_empty
    end
  end

  describe '#spice_names_for_display' do
    it 'returns spice category names when present' do
      dish = FactoryBot.create(:dish, name: '料理A')
      spice = Category.find_or_create_by!(name: 'クミン')
      FactoryBot.create(:category_content, dish: dish, category: spice, label: Dish::SPICE_LABEL)

      expect(dish.spice_names_for_display).to contain_exactly('クミン')
    end

    it 'falls back to provided names when spice categories are missing' do
      dish = FactoryBot.create(:dish, name: '料理B')
      result = dish.spice_names_for_display(fallback_names: [ '', 'オレガノ' ])
      expect(result).to eq([ 'オレガノ' ])
    end
  end

  describe '#category_names_for_label' do
    it 'returns category names for the requested label only' do
      dish = FactoryBot.create(:dish, name: 'ミネストローネ')
      home_scene = Category.find_or_create_by!(name: '内食')
      lunch = Category.find_or_create_by!(name: '昼')
      FactoryBot.create(:category_content, dish: dish, category: home_scene, label: Dish::SCENE_LABEL)
      FactoryBot.create(:category_content, dish: dish, category: lunch, label: Dish::TIME_LABEL)

      expect(dish.category_names_for_label(Dish::SCENE_LABEL)).to eq([ '内食' ])
    end
  end

  describe '.spices_for_name' do
    it 'handles blank and unknown names' do
      aggregate_failures do
        expect(Dish.spices_for_name('')).to eq([])
        expect(Dish.spices_for_name('未知の料理')).to eq([])
      end
    end
  end

  describe '.random_by_category' do
    it 'returns a dish from the given category' do
      washoku = FactoryBot.create(:category)
      dish1 = FactoryBot.create(:dish, name: '料理A')
      dish2 = FactoryBot.create(:dish, name: '料理B')
      FactoryBot.create(:category_content, dish: dish1, category: washoku)
      FactoryBot.create(:category_content, dish: dish2, category: washoku)

      result = Dish.random_by_category(washoku.name)
      expect([ dish1, dish2 ]).to include(result)
    end

    it 'returns nil when no dishes match the category' do
      category = FactoryBot.create(:category)
      expect(Dish.random_by_category(category.name)).to be_nil
    end
  end
end
