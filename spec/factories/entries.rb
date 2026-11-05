FactoryBot.define do
  factory :entry do
    user
    category
    description { "Salary" }
    amount_cents { 500_000 }
    due_on { Date.current }

    trait :paid do
      status { :paid }
      paid_on { due_on }
    end
  end
end
