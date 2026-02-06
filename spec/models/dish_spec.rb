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

  describe '.search_by_conditions' do
    let!(:keyword) { "spec-keyword-#{SecureRandom.hex(4)}" }
    let!(:main_category) { FactoryBot.create(:category) }
    let!(:spice_category_name) { "spec-spice-#{SecureRandom.hex(4)}" }
    let!(:spice_category) { FactoryBot.create(:category, name: spice_category_name) }

    let!(:matched_dish) do
      dish = FactoryBot.create(:dish, name: "#{keyword}-料理A", time_of_days: ['morning'])
      FactoryBot.create(:category_content, dish: dish, category: main_category)
      FactoryBot.create(:category_content, dish: dish, category: spice_category)
      dish
    end

    let!(:other_dish) do
      dish = FactoryBot.create(:dish, name: '料理B', time_of_days: ['night'])
      FactoryBot.create(:category_content, dish: dish, category: FactoryBot.create(:category))
      dish
    end

    it 'combines multiple filters' do
      other_dish
      result = Dish.search_by_conditions(
        keyword: keyword,
        category: main_category.name,
        time_of_day: 'morning',
        spice_name: spice_category_name
      )
      expect(result).to contain_exactly(matched_dish)
    end
  end

  describe '#spice_names_for_display' do
    it 'returns spice category names when present' do
      dish = FactoryBot.create(:dish, name: '料理A')
      spice = FactoryBot.create(:category, name: 'クミン')
      FactoryBot.create(:category_content, dish: dish, category: spice, label: Dish::SPICE_LABEL)

      expect(dish.spice_names_for_display).to contain_exactly('クミン')
    end

    it 'falls back to provided names when spice categories are missing' do
      dish = FactoryBot.create(:dish, name: '料理B')
      result = dish.spice_names_for_display(fallback_names: ['', 'オレガノ'])
      expect(result).to eq(['オレガノ'])
    end
  end

  describe '.spices_for_name' do
    it 'handles blank and unknown names' do
      aggregate_failures do
        expect(Dish.spices_for_name('')).to eq([])
        expect(Dish.spices_for_name('未知の料理')).to eq(['ブラックペッパー'])
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
      expect([dish1, dish2]).to include(result)
    end

    it 'returns nil when no dishes match the category' do
      category = FactoryBot.create(:category)
      expect(Dish.random_by_category(category.name)).to be_nil
    end
  end
end
