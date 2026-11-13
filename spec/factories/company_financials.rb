FactoryBot.define do
  factory :company_financial do
    cnpj { "33000167000101" }
    fiscal_year { 2025 }
    revenue_cents { 49_754_900_000_000 }
    net_income_cents { 11_060_500_000_000 }
    equity_cents { 41_758_700_000_000 }
    net_debt_cents { 33_341_700_000_000 }
    dividends_paid_cents { 4_520_500_000_000 }
    shares_count { 12_888_732_761 }
  end
end
