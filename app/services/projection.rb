class Projection
  MONTHS_RANGE = (1..24)
  DEFAULT_MONTHS = 12
  SIGNED_AMOUNT = Arel.sql("CASE WHEN kind = 'income' THEN amount_cents ELSE -amount_cents END")
  MONTH_OF_DUE_ON = Arel.sql("date_trunc('month', due_on)::date")

  attr_reader :anchor

  def initialize(user:, from:, months: DEFAULT_MONTHS, extra_entries: [])
    @entries = user.entries
    @extra_entries = extra_entries
    @from = from.beginning_of_month
    @months = months
    @anchor = user.balances.recent.first
  end

  def months
    @rows ||= begin
      start = opening = opening_balance
      month_starts.map do |month|
        row = month_row(month, opening, start)
        opening = row[:closing_cents]
        row
      end
    end
  end

  def alerts
    negative = months.select { |row| row[:negative] }
    { first_negative_month: negative.first&.fetch(:month), negative_months_count: negative.size }
  end

  private

  def month_row(month, opening, start)
    totals = monthly_totals.fetch(month, {})
    income = totals.fetch([ "income", nil ], 0)
    fixed = totals.fetch([ "expense", "fixed" ], 0)
    variable = totals.fetch([ "expense", "variable" ], 0)
    closing = opening + income - fixed - variable
    {
      month: month.strftime("%Y-%m"),
      opening_cents: opening,
      income_cents: income,
      expense_cents: fixed + variable,
      fixed_expense_cents: fixed,
      variable_expense_cents: variable,
      closing_cents: closing,
      savings_cents: closing - start,
      negative: closing.negative?
    }
  end

  def opening_balance
    return 0 unless anchor

    last_day = @from.prev_day
    return anchor.amount_cents + net_between(anchor.as_of, last_day) if last_day >= anchor.as_of

    anchor.amount_cents - net_between(last_day, anchor.as_of)
  end

  def net_between(after, through)
    range = after.next_day..through
    @entries.where(due_on: range).sum(SIGNED_AMOUNT) + @extra_entries.select { |entry| range.cover?(entry.due_on) }.sum { |entry| signed(entry) }
  end

  def signed(entry)
    entry.income? ? entry.amount_cents : -entry.amount_cents
  end

  def month_starts
    Array.new(@months) { |offset| @from >> offset }
  end

  def monthly_totals
    @monthly_totals ||= @entries
      .where(due_on: @from..month_starts.last.end_of_month)
      .group(MONTH_OF_DUE_ON, :kind, :nature)
      .sum(:amount_cents)
      .each_with_object(Hash.new { |hash, key| hash[key] = Hash.new(0) }) do |((month, kind, nature), cents), totals|
        totals[month][[ kind, nature ]] = cents
      end
      .tap { |totals| add_extra_entries(totals) }
  end

  def add_extra_entries(totals)
    period = @from..month_starts.last.end_of_month
    @extra_entries.each do |entry|
      next unless period.cover?(entry.due_on)

      totals[entry.due_on.beginning_of_month][[ entry.kind, entry.nature ]] += entry.amount_cents
    end
  end
end
