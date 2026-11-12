FactoryBot.define do
  factory :asset_distribution do
    asset factory: %i[asset fii]
    kind { :fii_income }
    source { :cvm }
    record_on { Date.new(2026, 9, 30) }
    amount_per_share_e8 { 110_000_000 }

    trait :manual do
      user { association :user, strategy: :create }
      asset { association :asset, strategy: :create }
      source { :manual }
      kind { :dividend }
      paid_on { record_on + 20 }
      after(:build) do |distribution|
        distribution.user.investment_positions.find_or_create_by!(asset: distribution.asset) if distribution.user && distribution.asset
      end
    end
  end
end
