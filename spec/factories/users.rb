FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "ユーザー#{n}" }
    password { "password123" }
    password_confirmation { "password123" }
  end
end
