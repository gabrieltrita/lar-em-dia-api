class ReserveGrowth
  PRECISION = 30
  ONE = BigDecimal(1)
  BUSINESS_DAYS_PER_YEAR = 252
  BPS = 10_000
  CDI_SPREAD_E8 = 100_000
  LAST_SAVINGS_ANNIVERSARY_DAY = 28
  TAX_BRACKETS = { 180 => BigDecimal("0.225"), 360 => BigDecimal("0.2"), 720 => BigDecimal("0.175") }.freeze
  LONG_TERM_TAX = BigDecimal("0.15")

  Curve = Data.define(:dates, :cumulative, :last_known, :gap_factor, :future_factor, :today) do
    def self.build(rows, last_known:, gap_factor:, future_factor:, today:)
      product = ONE
      cumulative = rows.map { |_date, factor| product = product.mult(factor, PRECISION) }
      new(dates: rows.map(&:first), cumulative: cumulative, last_known: last_known, gap_factor: gap_factor, future_factor: future_factor, today: today)
    end

    def factor(from, to)
      known = before(to).div(before(from), PRECISION)
      gap_start = last_known ? [ from, last_known.next_day ].max : from
      gap = gap_factor.power(ReserveGrowth.weekdays(gap_start, [ to.prev_day, today ].min), PRECISION)
      future = future_factor.power(ReserveGrowth.weekdays([ from, today.next_day ].max, to.prev_day), PRECISION)
      known.mult(gap, PRECISION).mult(future, PRECISION)
    end

    private

    def before(date)
      index = dates.bsearch_index { |day| day >= date } || dates.size
      index.zero? ? ONE : cumulative[index - 1]
    end
  end

  def self.tax_rate(days)
    TAX_BRACKETS.find { |limit, _rate| days <= limit }&.last || LONG_TERM_TAX
  end

  def self.weekdays(first, last)
    return 0 if last < first

    weeks, rest = ((last - first).to_i + 1).divmod(7)
    weeks * 5 + (0...rest).count { |offset| (first + offset).on_weekday? }
  end

  def self.annual_to_daily(annual)
    (ONE + annual).power(ONE / BUSINESS_DAYS_PER_YEAR, PRECISION)
  end

  attr_reader :today

  def initialize(since:, today: Date.current)
    @since = since
    @today = today
    @curves = {}
  end

  def factor(account, from, to)
    return ONE if to <= from || account.idle?
    return savings_factor(from, to) if account.savings?

    curve_for(account).factor(from, to)
  end

  def assumptions
    {
      selic_target_e8: latest(:selic_target)&.rate_e8,
      cdi_estimate_e8: latest(:selic_target) && [ latest(:selic_target).rate_e8 - CDI_SPREAD_E8, 0 ].max,
      savings_monthly_e8: latest(:savings)&.rate_e8,
      rates_as_of: latest(:selic)&.rate_on,
      holidays_ignored: true,
      iof_ignored: true
    }
  end

  private

  def curve_for(account)
    case account.kind
    when "cdb" then cdb_curve(BigDecimal(account.cdi_percent_bps) / BPS)
    when "fixed_rate" then fixed_curve(self.class.annual_to_daily(BigDecimal(account.annual_rate_bps) / BPS))
    else selic_curve
    end
  end

  def selic_curve
    @curves[:selic] ||= daily_curve(:selic, future: self.class.annual_to_daily(target)) { |rate| ONE + rate }
  end

  def cdb_curve(percent)
    @curves[[ :cdb, percent ]] ||= begin
      future_rate = self.class.annual_to_daily([ target - fraction(CDI_SPREAD_E8), 0 ].max) - ONE
      daily_curve(:cdi, future: ONE + future_rate * percent) { |rate| ONE + rate * percent }
    end
  end

  def fixed_curve(daily)
    @curves[[ :fixed, daily ]] ||= daily_curve(:selic, future: daily) { daily }
  end

  def daily_curve(series, future:, &factor)
    rows = InterestRate.between(series, @since..@today).map { |date, rate_e8| [ date, factor.call(fraction(rate_e8)) ] }
    last = latest(series)
    Curve.build(rows, last_known: last&.rate_on, gap_factor: last ? factor.call(last.fraction) : future, future_factor: future, today: @today)
  end

  def savings_factor(from, to)
    anniversary = from.day > LAST_SAVINGS_ANNIVERSARY_DAY ? from.next_month.beginning_of_month : from
    product = ONE
    while (following = anniversary >> 1) <= to
      product = product.mult(ONE + savings_rate(anniversary), PRECISION)
      anniversary = following
    end
    product
  end

  def savings_rate(date)
    @savings_rates ||= InterestRate.between(:savings, @since..@today).to_h { |day, rate_e8| [ day, fraction(rate_e8) ] }
    @savings_rates.fetch(date) { latest(:savings)&.fraction || 0 }
  end

  def target
    latest(:selic_target)&.fraction || 0
  end

  def latest(series)
    @latest ||= {}
    return @latest[series] if @latest.key?(series)

    @latest[series] = InterestRate.latest(series)
  end

  def fraction(rate_e8)
    BigDecimal(rate_e8) / InterestRate::E8
  end
end
