FactoryBot.define do
  factory :dish do
    sequence(:name) { |n| "料理#{n}" }
    time_of_days { [] }
    seasons { [] }
    moods { [] }
    genres { [] }
    cooking_styles { [] }
    healthiness_types { [] }
  end
end
