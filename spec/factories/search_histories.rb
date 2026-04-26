FactoryBot.define do
  factory :search_history do
    association :user
    query_params { {} }
    executed_at { Time.zone.now }
  end
end
