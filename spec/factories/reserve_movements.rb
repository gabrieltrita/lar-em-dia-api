FactoryBot.define do
  factory :reserve_movement do
    user
    account { association :reserve_account, user: user }
    kind { :deposit }
    moved_on { Date.new(2026, 10, 1) }
    amount_cents { 100_000 }
  end
end
