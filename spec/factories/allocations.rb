FactoryBot.define do
  factory :allocation do
    user
    target { association :allocation_target, user: user }
    month { Date.current.beginning_of_month }
    amount_cents { 1_000 }
    entry { association :entry, :paid, user: user, category: association(:category, :expense), amount_cents: 1_000 }
  end
end
