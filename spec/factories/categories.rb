FactoryBot.define do
  factory :category do
    kind { :income }
    sequence(:key) { |n| "category_#{n}" }
    name { "Category" }
    position { 0 }

    trait :expense do
      kind { :expense }
    end

    trait :inactive do
      active { false }
    end
  end
end
