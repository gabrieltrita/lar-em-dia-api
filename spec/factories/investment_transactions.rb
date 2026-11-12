FactoryBot.define do
  factory :investment_transaction do
    user
    position { association :investment_position, user: user }
    kind { :buy }
    traded_on { Date.new(2026, 10, 1) }
    quantity { 100 }
    price_cents { 1_000 }

    trait :split do
      kind { :split }
      price_cents { nil }
    end
  end
end
