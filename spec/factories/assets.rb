FactoryBot.define do
  factory :asset do
    sequence(:ticker) { |n| "TST#{('A'.ord + (n % 26)).chr}#{3 + (n % 7)}" }
    sequence(:isin) { |n| format("BRTEST%05d%d", n % 100_000, n % 10) }
    name { "Test company" }
    asset_type { :stock }

    trait :fii do
      sequence(:ticker) { |n| "FII#{('A'.ord + (n % 26)).chr}11" }
      asset_type { :fii }
      sector { "Logística" }
    end

    trait :inactive do
      active { false }
    end
  end
end
