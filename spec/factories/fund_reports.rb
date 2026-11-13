FactoryBot.define do
  factory :fund_report do
    asset factory: %i[asset fii]
    reference_month { Date.new(2026, 9, 1) }
    equity_cents { 754_601_779_739 }
    book_value_per_share_e8 { 16_547_663_017 }
    shares_count { 45_601_713 }
    shareholders_count { 613_837 }
  end
end
