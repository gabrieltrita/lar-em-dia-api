FactoryBot.define do
  factory :fund_composition do
    asset factory: %i[asset fii]
    reference_on { Date.new(2026, 9, 30) }
  end

  factory :fund_property do
    fund_composition
    name { "HGLG Betim Business Park" }
    kind { :rent }
    area_m2 { 35_331 }
    vacancy_bps { 0 }
    delinquency_bps { 0 }
    revenue_share_bps { 141 }
  end
end
