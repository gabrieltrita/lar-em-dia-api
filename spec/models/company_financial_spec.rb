require "rails_helper"

RSpec.describe CompanyFinancial do
  subject { create(:company_financial) }

  it { is_expected.to validate_uniqueness_of(:fiscal_year).scoped_to(:cnpj) }
  it { is_expected.to validate_numericality_of(:net_income_cents).only_integer }
  it { is_expected.to validate_numericality_of(:net_debt_cents).only_integer.allow_nil }
  it { is_expected.not_to allow_value("33.000.167/0001-01").for(:cnpj) }

  it "belongs to every listed class of the company through its CNPJ" do
    preferred = create(:asset, ticker: "PETR4", cnpj: subject.cnpj)

    expect(preferred.financials).to contain_exactly(subject)
  end
end
