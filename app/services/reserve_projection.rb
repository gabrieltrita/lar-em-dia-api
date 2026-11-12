class ReserveProjection
  MONTHS_RANGE = (1..60)
  DEFAULT_MONTHS = 12

  def initialize(user, months: DEFAULT_MONTHS, today: Date.current)
    @user = user
    @months = months
    @today = today
  end

  def months
    Array.new(@months) do |offset|
      month = @today.beginning_of_month >> offset
      values = ledgers.map { |ledger| [ ledger.account, ledger.value_on(month.end_of_month) ] }
      total = values.sum(ReserveLedger::Value.empty) { |_account, value| value }
      {
        month: month.strftime("%Y-%m"), gross_cents: total.gross_cents, net_cents: total.net_cents,
        accounts: values.map { |account, value| { id: account.id, gross_cents: value.gross_cents, net_cents: value.net_cents } }
      }
    end
  end

  def net_cents_on(date)
    ledgers.sum { |ledger| ledger.value_on(date).net_cents }
  end

  def assumptions
    ReserveGrowth.new(since: @today, today: @today).assumptions
  end

  private

  def ledgers
    @ledgers ||= ReserveLedger.for_user(@user, today: @today)
  end
end
