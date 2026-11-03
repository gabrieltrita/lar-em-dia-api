class Projection
  MONTHS_RANGE = (1..24)
  DEFAULT_MONTHS = 12
  SIGNED_AMOUNT = Arel.sql("CASE WHEN kind = 'income' THEN amount_cents ELSE -amount_cents END")
  MONTH_OF_DUE_ON = Arel.sql("date_trunc('month', due_on)::date")

  attr_reader :anchor

  def initialize(user:, from:, months: DEFAULT_MONTHS)
    @entries = user.entries
    @from = from.beginning_of_month
    @months = months
    @anchor = user.balances.recent.first
  end

  def months
    opening = opening_balance
    month_starts.map do |month|
      row = month_row(month, opening)
      opening = row[:closing_cents]
      row
    end
  end

  private

  def month_row(month, opening)
    totals = monthly_totals.fetch(month, {})
    income = totals.fetch([ "income", nil ], 0)
    fixed = totals.fetch([ "expense", "fixed" ], 0)
    variable = totals.fetch([ "expense", "variable" ], 0)
    {
      month: month.strftime("%Y-%m"),
      opening_cents: opening,
      income_cents: income,
      expense_cents: fixed + variable,
      fixed_expense_cents: fixed,
      variable_expense_cents: variable,
      closing_cents: opening + income - fixed - variable
    }
  end

  def opening_balance
    return 0 unless anchor

    last_day = @from.prev_day
    return anchor.amount_cents + net_between(anchor.as_of, last_day) if last_day >= anchor.as_of

    anchor.amount_cents - net_between(last_day, anchor.as_of)
  end

  def net_between(after, through)
    @entries.where(due_on: after.next_day..through).sum(SIGNED_AMOUNT)
  end

  def month_starts
    Array.new(@months) { |offset| @from >> offset }
  end

  def monthly_totals
    @monthly_totals ||= @entries
      .where(due_on: @from..month_starts.last.end_of_month)
      .group(MONTH_OF_DUE_ON, :kind, :nature)
      .sum(:amount_cents)
      .each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |((month, kind, nature), cents), totals|
        totals[month][[ kind, nature ]] = cents
      end
  end
end
