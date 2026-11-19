class AssetIndicators
  BPS = 10_000
  E2 = 100
  LIQUIDITY_DAYS = 30
  DISTRIBUTION_MONTHS = 12
  GROWTH_YEARS = 5
  AVERAGE_YEARS = 5
  MIN_GROWTH_SPAN = 2
  MIN_PRICE_TO_BOOK = Rational(1, 100)
  SHARES_IN_THOUSANDS = 1000
  PRECISION = 20

  def self.refresh(today: Date.current)
    new(today: today).refresh
  end

  def initialize(today:)
    @today = today
    @now = Time.current
  end

  def refresh
    assets = Asset.listed.to_a
    rows = assets.map { |asset| row(asset) }
    AssetIndicator.transaction do
      AssetIndicator.where.not(asset_id: assets.map(&:id)).delete_all
      AssetIndicator.upsert_all(rows, unique_by: :asset_id, update_only: rows.first.keys - %i[asset_id created_at updated_at]) if rows.any?
    end
    rows.size
  end

  private

  def row(asset)
    price = prices[asset.id]
    figures = asset.fii? ? fund_figures(asset, price) : company_figures(asset, price)
    blank.merge(figures).merge(asset_id: asset.id, computed_on: @today, price_cents: price, liquidity_cents: liquidity[asset.id],
      created_at: @now, updated_at: @now)
  end

  def blank
    AssetIndicator.column_names.map(&:to_sym).without(:id, :asset_id, :created_at, :updated_at).index_with(nil)
  end

  def fund_figures(asset, price)
    amounts = recent_distributions.fetch(asset.id, []).map(&:last)
    {
      dy_12m_bps: ratio(amounts.presence&.sum, price&.*(AssetDistribution::E8_PER_CENT), BPS),
      distribution_average_e8: ratio(amounts.presence&.sum, amounts.size, 1),
      distribution_median_e8: median(amounts),
      years_paying: current_streak(paying_years.fetch(asset.id, [])),
      p_vp_e2: ratio(price&.*(AssetDistribution::E8_PER_CENT), fund_reports[asset.id]&.book_value_per_share_e8, E2)
    }
  end

  def company_figures(asset, price)
    history = financials.fetch(asset.cnpj, [])
    latest = history.last
    return {} unless latest

    cap = market_cap(price, latest)
    recent = history.select { |financial| financial.fiscal_year > latest.fiscal_year - AVERAGE_YEARS }
    {
      dy_12m_bps: ratio(latest.dividends_paid_cents, cap, BPS),
      payout_bps: ratio(latest.dividends_paid_cents, latest.net_income_cents, BPS),
      years_paying: consecutive_years(history.select { |financial| financial.dividends_paid_cents.to_i.positive? }.map(&:fiscal_year)),
      p_vp_e2: ratio(cap, latest.equity_cents, E2),
      p_l_e2: ratio(cap, latest.net_income_cents, E2),
      roe_average_bps: average_roe(recent),
      earnings_cagr_bps: cagr(history, latest, &:net_income_cents),
      equity_cagr_bps: cagr(history, latest, &:equity_cents),
      years_with_profit: recent.count { |financial| financial.net_income_cents.positive? },
      net_margin_bps: ratio(latest.net_income_cents, latest.revenue_cents, BPS),
      net_debt_to_equity_bps: ratio(latest.net_debt_cents, latest.equity_cents, BPS),
      financial_years: recent.size
    }
  end

  def market_cap(price, financial)
    return unless price && financial.shares_count

    cap = price * financial.shares_count
    cap < financial.equity_cents * MIN_PRICE_TO_BOOK ? cap * SHARES_IN_THOUSANDS : cap
  end

  def average_roe(financials)
    returns = financials.select { |financial| financial.equity_cents.positive? }.map { |financial| financial.net_income_cents.to_r / financial.equity_cents }
    returns.any? ? (returns.sum / returns.size * BPS).round : nil
  end

  def cagr(history, latest)
    first = history.find { |financial| financial.fiscal_year >= latest.fiscal_year - GROWTH_YEARS }
    span = latest.fiscal_year - first.fiscal_year
    start = yield(first)
    finish = yield(latest)
    return unless span >= MIN_GROWTH_SPAN && start.positive? && finish.positive?

    ((BigDecimal(finish) / start).power(BigDecimal(1) / span, PRECISION) - 1).mult(BPS, PRECISION).round
  end

  def ratio(numerator, denominator, scale)
    return unless numerator && denominator&.positive?

    (numerator.to_r * scale / denominator).round
  end

  def median(amounts)
    return if amounts.empty?

    sorted = amounts.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : ((sorted[middle - 1] + sorted[middle]).to_r / 2).round
  end

  def current_streak(years)
    years.max.to_i >= @today.year - 1 ? consecutive_years(years) : 0
  end

  def consecutive_years(years)
    newest_first = years.uniq.sort.reverse
    return 0 if newest_first.empty?

    newest_first.each_cons(2).take_while { |newer, older| newer - older == 1 }.size + 1
  end

  def prices
    @prices ||= AssetQuote.select("DISTINCT ON (asset_id) asset_id, close_cents").order(:asset_id, quoted_on: :desc)
      .to_h { |quote| [ quote.asset_id, quote.close_cents ] }
  end

  def liquidity
    @liquidity ||= AssetQuote.where(quoted_on: (@today - LIQUIDITY_DAYS)..@today).group(:asset_id).average(:volume_cents)
      .transform_values(&:round)
  end

  def cvm_distributions
    AssetDistribution.where(source: "cvm", user_id: nil)
  end

  def recent_distributions
    @recent_distributions ||= cvm_distributions.where(record_on: (@today << DISTRIBUTION_MONTHS)..@today)
      .pluck(:asset_id, :amount_per_share_e8).group_by(&:first)
  end

  def paying_years
    @paying_years ||= cvm_distributions.distinct.pluck(:asset_id, Arel.sql("EXTRACT(YEAR FROM record_on)::integer"))
      .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
  end

  def fund_reports
    @fund_reports ||= FundReport.select("DISTINCT ON (asset_id) asset_id, book_value_per_share_e8").order(:asset_id, reference_month: :desc)
      .index_by(&:asset_id)
  end

  def financials
    @financials ||= CompanyFinancial.order(:fiscal_year).group_by(&:cnpj)
  end
end
