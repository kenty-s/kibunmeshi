FactoryBot.define do
  factory :dish do
    sequence(:name) { |n| "料理#{n}" }
  end
end
