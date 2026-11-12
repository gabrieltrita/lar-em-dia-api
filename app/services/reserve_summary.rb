class ReserveSummary
  CLOSED_MONTHS = 3
  UPCOMING_MONTHS = 3

  def initialize(user, today: Date.current)
    @user = user
    @today = today
  end

  def to_h
    {
      totals: totals.to_h,
      accounts: values.map { |account, value| ReserveAccountBlueprint.render_as_hash(account).merge(value.to_h) },
      suggestion: suggestion,
      goal: { months: @user.reserve_goal_months, cents: @user.reserve_goal_cents, target_cents: target_cents },
      alerts: alerts,
      rates_as_of: InterestRate.latest(:selic)&.rate_on
    }
  end

  private

  def values
    @values ||= ReserveLedger.for_user(@user, today: @today).map { |ledger| [ ledger.account, ledger.value_on(@today) ] }
  end

  def totals
    @totals ||= values.sum(ReserveLedger::Value.empty) { |_account, value| value }
  end

  def suggestion
    return @suggestion if defined?(@suggestion)

    @suggestion = fixed_by_month.empty? ? nil : suggestion_for((fixed_by_month.values.sum / fixed_by_month.size.to_r).round)
  end

  def suggestion_for(average)
    {
      average_fixed_cents: average,
      months_counted: fixed_by_month.size,
      goal_months: @user.reserve_goal_months,
      suggested_cents: average * @user.reserve_goal_months,
      coverage_months_e2: (totals.net_cents * 100 / average.to_r).round
    }
  end

  def fixed_by_month
    @fixed_by_month ||= begin
      current = @today.beginning_of_month
      @user.entries.expense.fixed.where(due_on: (current << CLOSED_MONTHS)...(current >> UPCOMING_MONTHS))
        .group(Projection::MONTH_OF_DUE_ON).sum(:amount_cents)
    end
  end

  def target_cents
    @user.reserve_goal_cents || suggestion&.fetch(:suggested_cents)
  end

  def alerts
    [
      ("no_reserve" if suggestion && values.empty?),
      ("below_suggestion" if values.any? && target_cents && totals.net_cents < target_cents),
      ("idle_money" if values.any? { |account, value| account.idle? && value.gross_cents.positive? })
    ].compact
  end
end
