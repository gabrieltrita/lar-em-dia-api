class PortfolioHistory
  MAX_MONTHS = 120

  def initialize(user:, today: Date.current)
    @user = user
    @today = today
  end

  def months
    positions = @user.investment_positions.includes(:transactions).to_a
    first = positions.flat_map(&:transactions).map(&:traded_on).min
    return [] unless first

    month_ends = month_ends_since(first)
    closes = closes_by_asset(positions.map(&:asset_id))
    states = positions.to_h { |position| [ position, PositionLedger.new(position.transactions).states_on(month_ends) ] }
    month_ends.each_with_index.map { |month_end, index| month(month_end, index, states, closes) }
  end

  private

  def month_ends_since(first)
    start = [ first.beginning_of_month, (@today << (MAX_MONTHS - 1)).beginning_of_month ].max
    Array.new(((@today.year * 12) + @today.month) - ((start.year * 12) + start.month) + 1) do |offset|
      [ (start >> offset).end_of_month, @today ].min
    end
  end

  def closes_by_asset(asset_ids)
    AssetQuote.month_end_closes(asset_ids, @today).group_by(&:asset_id).transform_values do |quotes|
      quotes.sort_by(&:quoted_on)
    end
  end

  def month(month_end, index, states, closes)
    value = states.sum { |position, list| market_value(list[index], closes[position.asset_id], month_end) }
    {
      month: month_end.strftime("%Y-%m"),
      contributed_cents: states.sum { |_position, list| list[index].contributed_cents },
      market_value_cents: value
    }
  end

  def market_value(state, quotes, month_end)
    close = quotes&.reverse_each&.find { |quote| quote.quoted_on <= month_end }
    close ? state.quantity * close.close_cents : state.cost_cents
  end
end
