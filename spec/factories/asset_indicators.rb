FactoryBot.define do
  factory :asset_indicator do
    asset
    computed_on { Date.new(2026, 11, 11) }
  end
end
