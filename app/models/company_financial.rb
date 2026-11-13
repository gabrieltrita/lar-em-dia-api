class CompanyFinancial < ApplicationRecord
  validates :cnpj, presence: true, format: { with: Asset::CNPJ_FORMAT }
  validates :fiscal_year, presence: true, uniqueness: { scope: :cnpj }
  validates :revenue_cents, :net_income_cents, :equity_cents, numericality: { only_integer: true }
  validates :net_debt_cents, :dividends_paid_cents, :shares_count, numericality: { only_integer: true }, allow_nil: true
end
