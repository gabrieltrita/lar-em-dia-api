class AssetScreener
  RANGES = %i[
    dy_12m_bps payout_bps p_vp_e2 p_l_e2 roe_average_bps earnings_cagr_bps equity_cagr_bps net_margin_bps net_debt_to_equity_bps
    liquidity_cents years_paying years_with_profit
  ].freeze
  SORTS = (RANGES + %i[ticker]).freeze
  DIRECTIONS = %w[asc desc].freeze

  attr_reader :error

  def initialize(params)
    @params = params
  end

  def apply(scope)
    bounds = RANGES.flat_map { |field| %w[min max].map { |side| [ field, side, @params[:"#{field}_#{side}"] ] } }.select { |*, value| value.present? }
    return fail_with("invalid_filter") unless bounds.all? { |*, value| integer(value) }
    return fail_with("invalid_sort") unless sort_valid?

    scope = scope.left_joins(:indicator).includes(:indicator)
    scope = scope.where(asset_indicators: { dy_12m_bps: 1.. }) if @params[:paying] == "true"
    scope = bounds.reduce(scope) { |filtered, (field, side, value)| filtered.where(asset_indicators: { field => range(side, integer(value)) }) }
    sorted(scope)
  end

  private

  def sort_valid?
    sort = @params[:sort]
    (sort.blank? || SORTS.include?(sort.to_sym)) && (@params[:direction].blank? || DIRECTIONS.include?(@params[:direction]))
  end

  def sorted(scope)
    sort = (@params[:sort].presence || "ticker").to_sym
    direction = @params[:direction].presence || (sort == :ticker ? "asc" : "desc")
    return scope.reorder(ticker: direction) if sort == :ticker

    scope.reorder(AssetIndicator.arel_table[sort].public_send(direction).nulls_last, :ticker)
  end

  def range(side, value)
    side == "min" ? value.. : ..value
  end

  def integer(value)
    Integer(value.to_s, 10, exception: false)
  end

  def fail_with(code)
    @error = code
    nil
  end
end
