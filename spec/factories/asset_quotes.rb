FactoryBot.define do
  factory :asset_quote do
    asset
    sequence(:quoted_on) { |n| Date.new(2026, 11, 11) - n }
    close_cents { 4_355 }
    volume_cents { 285_494_368_900 }
    trades_count { 96_974 }
  end
end
