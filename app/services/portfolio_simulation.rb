class PortfolioSimulation
  include ActiveModel::Model
  include ActiveModel::Attributes

  KINDS = %w[income growth].freeze
  MONTHS = 1..600
  MAX_CENTS = 100_000_000_000
  ANNUAL_RATES = -9_999..10_000
  MONTHLY_YIELDS = 1..1_000
  BPS = 10_000
  PRECISION = 20
  YIELD_SHARE_CENTS = 100

  attribute :kind, :string
  attribute :initial_cents, :integer, default: 0
  attribute :monthly_cents, :integer, default: 0
  attribute :months, :integer
  attribute :ticker, :string
  attribute :monthly_yield_bps, :integer
  attribute :annual_rate_bps, :integer
  attribute :reinvest, :boolean, default: true
  attribute :target_monthly_income_cents, :integer

  validates :kind, inclusion: { in: KINDS }
  validates :months, presence: true, numericality: { in: MONTHS }
  validates :initial_cents, :monthly_cents, numericality: { in: 0..MAX_CENTS }
  validates :target_monthly_income_cents, numericality: { in: 1..MAX_CENTS }, allow_nil: true
  validates :annual_rate_bps, presence: true, numericality: { in: ANNUAL_RATES }, if: -> { kind == "growth" }
  validates :monthly_yield_bps, numericality: { in: MONTHLY_YIELDS }, allow_nil: true
  validate :something_invested
  validate :income_source, if: -> { kind == "income" }

  def result
    kind == "income" ? income : growth
  end

  private

  def something_invested
    errors.add(:monthly_cents, :blank) if initial_cents.to_i.zero? && monthly_cents.to_i.zero?
  end

  def income_source
    return errors.add(:monthly_yield_bps, :blank) if ticker.blank? && monthly_yield_bps.nil?
    return if ticker.blank?

    @asset = Asset.listed.includes(:indicator).find_by(ticker: ticker.upcase)
    return errors.add(:ticker, :unknown_asset, message: :unknown_asset) unless @asset

    errors.add(:ticker, :no_income_data, message: :no_income_data) unless share_price && share_income_e8&.positive?
  end

  def share_price
    @asset ? @asset.indicator&.price_cents : YIELD_SHARE_CENTS
  end

  def share_income_e8
    return Rational(YIELD_SHARE_CENTS * AssetDistribution::E8_PER_CENT * monthly_yield_bps, BPS) unless @asset

    indicator = @asset.indicator
    return indicator.distribution_average_e8 if @asset.fii?

    indicator.dy_12m_bps && Rational(indicator.price_cents * AssetDistribution::E8_PER_CENT * indicator.dy_12m_bps, BPS * 12)
  end

  def income
    price = share_price
    per_share = Rational(share_income_e8, AssetDistribution::E8_PER_CENT)
    cash = Rational(initial_cents)
    shares = 0
    received = 0
    rows = (1..months).map do |month|
      cash += monthly_cents
      bought = (cash / price).floor
      shares += bought
      cash -= bought * price
      monthly_income = shares * per_share
      received += monthly_income
      cash += monthly_income if reinvest
      { month: month, contributed_cents: initial_cents + monthly_cents * month, shares: @asset && shares,
        value_cents: (shares * price + cash).round, income_cents: monthly_income.round, received_cents: received.round }
    end
    target_shares = target_monthly_income_cents && (target_monthly_income_cents / per_share).ceil
    {
      kind: "income", ticker: @asset&.ticker, price_cents: @asset && price, monthly_income_per_share_e8: @asset && share_income_e8.round,
      monthly_yield_bps: @asset ? nil : monthly_yield_bps, reinvest: reinvest, months: rows,
      summary: {
        contributed_cents: rows.last[:contributed_cents], value_cents: rows.last[:value_cents], monthly_income_cents: rows.last[:income_cents],
        received_cents: rows.last[:received_cents], target_monthly_income_cents: target_monthly_income_cents,
        shares_for_target: @asset && target_shares, capital_for_target_cents: target_shares && target_shares * price,
        months_to_target: target_monthly_income_cents && rows.find { |row| row[:income_cents] >= target_monthly_income_cents }&.dig(:month)
      }
    }
  end

  def growth
    rate = (1 + BigDecimal(annual_rate_bps) / BPS).power(BigDecimal(1) / 12, PRECISION) - 1
    value = BigDecimal(initial_cents)
    rows = (1..months).map do |month|
      value = value * (1 + rate) + monthly_cents
      contributed = initial_cents + monthly_cents * month
      { month: month, contributed_cents: contributed, value_cents: value.round, earnings_cents: value.round - contributed }
    end
    {
      kind: "growth", annual_rate_bps: annual_rate_bps, monthly_rate_e8: (rate * 100_000_000).round, months: rows,
      summary: rows.last.except(:month)
    }
  end
end
