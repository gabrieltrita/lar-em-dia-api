class DistributionIncome
  MONTHS_RANGE = (1..60)
  DEFAULT_MONTHS = 12
  WINDOW_MONTHS = 12

  Item = Data.define(:position, :ledger, :distributions) do
    def quantity = ledger.state.quantity
    def quantity_on(date) = ledger.states_on([ date ]).first.quantity
    def paid_in(month) = distributions.select { |distribution| distribution.payment_month == month }
  end

  def initialize(user:, today: Date.current)
    @user = user
    @current = today.beginning_of_month
    @window = (@current << (WINDOW_MONTHS - 1))..@current
  end

  def received
    months_of_window.map { |month| { month: month.strftime("%Y-%m"), amount_cents: cents(items.sum { |item| received_e8(item, month) }) } }
  end

  def forecast(months = DEFAULT_MONTHS)
    Array.new(months) do |offset|
      month = @current >> (offset + 1)
      { month: month.strftime("%Y-%m"), amount_cents: forecast_cents(month) }
    end
  end

  def forecast_cents(month)
    return 0 unless month > @current

    cents(items.sum { |item| forecast_e8(item, month) })
  end

  def monthly_average_cents
    cents(items.sum { |item| received_in_window_e8(item) } / WINDOW_MONTHS)
  end

  def positions
    items.map do |item|
      {
        ticker: item.position.ticker, goal: item.position.goal, quantity: item.quantity,
        received_12m_cents: cents(received_in_window_e8(item)), monthly_forecast_cents: cents(item.quantity * average_per_share_e8(item))
      }
    end
  end

  private

  def months_of_window
    Array.new(WINDOW_MONTHS) { |offset| @window.begin >> offset }
  end

  def received_e8(item, month)
    item.paid_in(month).sum(0) { |distribution| item.quantity_on(distribution.record_on) * distribution.net_per_share_e8 }
  end

  def received_in_window_e8(item)
    months_of_window.sum(0) { |month| received_e8(item, month) }
  end

  def forecast_e8(item, month)
    announced = item.paid_in(month)
    per_share = announced.any? ? announced.sum(0, &:net_per_share_e8) : average_per_share_e8(item)
    item.quantity * per_share
  end

  def average_per_share_e8(item)
    item.distributions.select { |distribution| @window.cover?(distribution.payment_month) }.sum(0, &:net_per_share_e8) / WINDOW_MONTHS
  end

  def cents(e8)
    Rational(e8, AssetDistribution::E8_PER_CENT).round
  end

  def items
    @items ||= begin
      positions = @user.investment_positions.includes(:asset, :transactions).joins(:asset).order("assets.ticker").to_a
      distributions = AssetDistribution.visible_to(@user).where(asset_id: positions.map(&:asset_id), record_on: (@window.begin << 1)..)
        .group_by(&:asset_id)
      positions.map do |position|
        Item.new(position: position, ledger: PositionLedger.new(position.transactions), distributions: distributions.fetch(position.asset_id, []))
      end
    end
  end
end
