FactoryBot.define do
  factory :category_content do
    dish
    category
    label { nil }
  end
end
