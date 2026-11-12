class PositionLedger
  CENTS_TO_E8 = 1_000_000

  State = Data.define(:quantity, :cost_cents, :contributed_cents, :realized_cents) do
    def self.empty = new(quantity: 0, cost_cents: 0, contributed_cents: 0, realized_cents: 0)

    def average_price_e8
      return 0 if quantity.zero?

      (cost_cents * CENTS_TO_E8 / quantity.to_r).round
    end
  end

  def initialize(transactions)
    @transactions = transactions.sort_by { |transaction| [ transaction.traded_on, transaction.created_at || Time.current ] }
  end

  def state
    states.last || State.empty
  end

  def states_on(dates)
    index = 0
    current = State.empty
    dates.map do |date|
      while index < @transactions.size && @transactions[index].traded_on <= date
        current = states[index]
        index += 1
      end
      current
    end
  end

  def shortfall?
    states.any? { |state| state.quantity.negative? }
  end

  private

  def states
    @states ||= @transactions.each_with_object([]) { |transaction, list| list << apply(list.last || State.empty, transaction) }
  end

  def apply(state, transaction)
    case transaction.kind
    when "buy" then buy(state, transaction)
    when "sell" then sell(state, transaction)
    when "reverse_split" then resize(state, -transaction.quantity)
    else resize(state, transaction.quantity)
    end
  end

  def buy(state, transaction)
    state.with(
      quantity: state.quantity + transaction.quantity,
      cost_cents: state.cost_cents + transaction.amount_cents,
      contributed_cents: state.contributed_cents + transaction.amount_cents
    )
  end

  def sell(state, transaction)
    quantity = state.quantity - transaction.quantity
    return state.with(quantity: quantity) if quantity.negative?

    removed = quantity.zero? ? state.cost_cents : (state.cost_cents * transaction.quantity / state.quantity.to_r).round
    state.with(
      quantity: quantity,
      cost_cents: state.cost_cents - removed,
      contributed_cents: state.contributed_cents - transaction.amount_cents,
      realized_cents: state.realized_cents + transaction.amount_cents - removed
    )
  end

  def resize(state, change)
    quantity = state.quantity + change
    state.with(quantity: quantity, cost_cents: quantity.positive? ? state.cost_cents : 0)
  end
end
