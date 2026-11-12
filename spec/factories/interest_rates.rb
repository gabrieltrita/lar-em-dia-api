FactoryBot.define do
  factory :interest_rate do
    series { :selic }
    rate_on { Date.new(2026, 10, 1) }
    rate_e8 { 50_788 }
  end
end
