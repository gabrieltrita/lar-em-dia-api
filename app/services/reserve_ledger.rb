class ReserveLedger
  Lot = Struct.new(:started_on, :principal)

  Value = Data.define(:gross_cents, :invested_cents, :tax_cents) do
    def self.empty = new(gross_cents: 0, invested_cents: 0, tax_cents: 0)

    def net_cents = gross_cents - tax_cents
    def yield_cents = gross_cents - invested_cents

    def +(other)
      with(gross_cents: gross_cents + other.gross_cents, invested_cents: invested_cents + other.invested_cents, tax_cents: tax_cents + other.tax_cents)
    end

    def to_h = { gross_cents: gross_cents, net_cents: net_cents, invested_cents: invested_cents, yield_cents: yield_cents, tax_cents: tax_cents }
  end

  attr_reader :account

  def self.for(account, movements, today: Date.current)
    new(account, movements, ReserveGrowth.new(since: movements.filter_map(&:moved_on).min || today, today: today))
  end

  def self.for_user(user, today: Date.current)
    accounts = user.reserve_accounts.ordered.includes(:movements).to_a
    since = accounts.flat_map { |account| account.movements.map(&:moved_on) }.min || today
    growth = ReserveGrowth.new(since: since, today: today)
    accounts.map { |account| new(account, account.movements.to_a, growth) }
  end

  def initialize(account, movements, growth)
    @account = account
    @growth = growth
    @movements = movements.sort_by { |movement| [ movement.moved_on, movement.created_at || Time.current ] }
  end

  def value_on(date)
    lots, = replay(@movements.select { |movement| movement.moved_on <= date })
    gross = lots.sum(BigDecimal(0)) { |lot| gross(lot, date) }
    tax = @account.exempt? ? 0 : lots.sum(BigDecimal(0)) { |lot| tax(lot, date) }
    Value.new(gross_cents: gross.round, invested_cents: lots.sum(BigDecimal(0), &:principal).round, tax_cents: tax.round)
  end

  def shortfall?
    replay(@movements).last
  end

  private

  def replay(movements)
    movements.each_with_object([ [], false ]) do |movement, state|
      case movement.kind
      when "anchor" then state[0] = [ lot_for(movement) ]
      when "deposit" then state[0] << lot_for(movement)
      else state[1] = true unless withdraw(state[0], movement)
      end
    end
  end

  def lot_for(movement)
    Lot.new(movement.moved_on, BigDecimal(movement.amount_cents))
  end

  def withdraw(lots, movement)
    values = lots.map { |lot| gross(lot, movement.moved_on) }
    return false if movement.amount_cents > values.sum(BigDecimal(0)).round

    remaining = BigDecimal(movement.amount_cents)
    while remaining.positive? && lots.any?
      value = values.shift
      if value <= remaining
        remaining -= value
        lots.shift
      else
        lots.first.principal = lots.first.principal.mult(ReserveGrowth::ONE - remaining.div(value, ReserveGrowth::PRECISION), ReserveGrowth::PRECISION)
        remaining = 0
      end
    end
    true
  end

  def gross(lot, date)
    lot.principal.mult(@growth.factor(@account, lot.started_on, date), ReserveGrowth::PRECISION)
  end

  def tax(lot, date)
    gain = gross(lot, date) - lot.principal
    gain.positive? ? gain * ReserveGrowth.tax_rate((date - lot.started_on).to_i) : 0
  end
end
