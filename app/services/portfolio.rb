class Portfolio
  Position = Data.define(:position, :state, :quote) do
    def market_value_cents = quote ? state.quantity * quote.close_cents : state.cost_cents
    def gain_cents = market_value_cents - state.cost_cents
  end

  def initialize(user:, goal: nil, include_closed: false)
    @user = user
    @goal = goal
    @include_closed = include_closed
  end

  def positions
    @positions ||= begin
      all = scope.map { |position| Position.new(position: position, state: PositionLedger.new(position.transactions).state, quote: nil) }
      open = @include_closed ? all : all.reject { |item| item.state.quantity.zero? }
      quotes = AssetQuote.latest_per_asset(open.map { |item| item.position.asset_id }).index_by(&:asset_id)
      open.map { |item| item.with(quote: quotes[item.position.asset_id]) }
    end
  end

  def totals
    summarize(positions)
  end

  def goals
    InvestmentPosition.goals.keys.index_with { |goal| summarize(positions.select { |item| item.position.goal == goal }) }
  end

  private

  def scope
    positions = @user.investment_positions.includes(:asset, :transactions).joins(:asset).order("assets.ticker")
    InvestmentPosition.goals.key?(@goal) ? positions.where(goal: @goal) : positions
  end

  def summarize(items)
    cost = items.sum { |item| item.state.cost_cents }
    value = items.sum(&:market_value_cents)
    {
      contributed_cents: items.sum { |item| item.state.contributed_cents },
      cost_cents: cost,
      market_value_cents: value,
      gain_cents: value - cost,
      realized_cents: items.sum { |item| item.state.realized_cents }
    }
  end
end
