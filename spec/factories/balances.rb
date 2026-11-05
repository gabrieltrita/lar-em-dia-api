FactoryBot.define do
  factory :balance do
    user
    amount_cents { 150_000 }
    sequence(:as_of) { |n| Date.current - n.days }
  end
end
