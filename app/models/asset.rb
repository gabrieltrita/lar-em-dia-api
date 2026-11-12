class Asset < ApplicationRecord
  TICKER_FORMAT = /\A[A-Z][A-Z0-9]{3}\d{1,2}B?\z/
  ISIN_FORMAT = /\A[A-Z]{2}[A-Z0-9]{9}\d\z/
  CNPJ_FORMAT = /\A\d{14}\z/
  NAME_LIMIT = 100
  INACTIVE_AFTER = 30.days

  has_many :quotes, class_name: "AssetQuote", dependent: :destroy, inverse_of: :asset
  has_one :latest_quote, -> { order(quoted_on: :desc) }, class_name: "AssetQuote", inverse_of: :asset
  has_many :distributions, class_name: "AssetDistribution", dependent: :destroy, inverse_of: :asset
  has_many :fund_reports, dependent: :destroy
  has_one :latest_fund_report, -> { order(reference_month: :desc) }, class_name: "FundReport", inverse_of: :asset

  enum :asset_type, { fii: "fii", stock: "stock" }, validate: true

  validates :ticker, presence: true, uniqueness: true, format: { with: TICKER_FORMAT }
  validates :isin, presence: true, format: { with: ISIN_FORMAT }
  validates :name, presence: true, length: { maximum: NAME_LIMIT }
  validates :cnpj, format: { with: CNPJ_FORMAT }, allow_nil: true
  validates :sector, length: { maximum: NAME_LIMIT }, allow_nil: true

  scope :listed, -> { where(active: true) }
  scope :ordered, -> { order(:ticker) }

  def self.search(term)
    term = sanitize_sql_like(term.to_s.strip.upcase)
    where("ticker LIKE :prefix OR UPPER(name) LIKE :anywhere", prefix: "#{term}%", anywhere: "%#{term}%")
  end
end
