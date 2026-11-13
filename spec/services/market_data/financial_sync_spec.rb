require "rails_helper"

RSpec.describe MarketData::FinancialSync do
  def financial(**attributes)
    MarketData::CvmFinancials::Financial.new(
      cnpj: "33000167000101", fiscal_year: 2025, revenue_cents: 49_754_900_000_000, net_income_cents: 11_060_500_000_000,
      equity_cents: 41_758_700_000_000, net_debt_cents: 33_341_700_000_000, dividends_paid_cents: 4_520_500_000_000,
      shares_count: 12_888_732_761, **attributes
    )
  end

  it "saves one row per company and year, updating a resubmitted year" do
    expect(described_class.call([ financial, financial(fiscal_year: 2024) ])).to eq(2)
    expect(described_class.call([ financial(net_income_cents: 1, net_debt_cents: nil) ])).to eq(1)

    expect(CompanyFinancial.find_by!(fiscal_year: 2025)).to have_attributes(net_income_cents: 1, net_debt_cents: nil)
    expect(CompanyFinancial.count).to eq(2)
  end

  it "saves nothing without financials" do
    expect(described_class.call([])).to eq(0)
  end
end
