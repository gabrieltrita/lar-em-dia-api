class Projection
  MONTHS_RANGE = (1..60)
  DEFAULT_MONTHS = 12
  ALL_MONTHS = :all
  ALL_MONTHS_LIMIT = 60
  SIGNED_AMOUNT = Arel.sql("CASE WHEN kind = 'income' THEN amount_cents ELSE -amount_cents END")
  MONTH_OF_DUE_ON = Arel.sql("date_trunc('month', due_on)::date")

  attr_reader :anchor

  def initialize(user:, from:, months: DEFAULT_MONTHS, extra_entries: [], include_investment_income: true)
    @user = user
    @entries = user.entries
    @extra_entries = extra_entries
    @from = from.beginning_of_month
    @anchor = user.balances.recent.first
    @reserve = ReserveProjection.new(user)
    @include_investment_income = include_investment_income
    @months = months == ALL_MONTHS ? months_until_last_entry : months
  end

  def last_entry_month
    last_due_on&.strftime("%Y-%m")
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
    investment_income = @include_investment_income ? distribution_income.forecast_cents(month) : 0
    income = totals.fetch([ "income", nil ], 0) + investment_income
    fixed = totals.fetch([ "expense", "fixed" ], 0)
    variable = totals.fetch([ "expense", "variable" ], 0)
    closing = opening + income - fixed - variable
    reserve = @reserve.net_cents_on(month.end_of_month)
    investments = investments_value_cents(month)
    {
      month: month.strftime("%Y-%m"),
      opening_cents: opening,
      income_cents: income,
      expense_cents: fixed + variable,
      fixed_expense_cents: fixed,
      variable_expense_cents: variable,
      closing_cents: closing,
      savings_cents: closing - start,
      negative: closing.negative?,
      reserve_cents: reserve,
      investment_income_cents: investment_income,
      investments_value_cents: investments,
      net_worth_cents: closing + reserve + investments,
      expense_by_category: expense_by_category(month)
    }
  end

  def distribution_income
    @distribution_income ||= DistributionIncome.new(user: @user)
  end

  def investments_value_cents(month)
    key = month.strftime("%Y-%m")
    portfolio_values.fetch(key) { key > portfolio_values.keys.max.to_s ? portfolio_values.values.last.to_i : 0 }
  end

  def portfolio_values
    @portfolio_values ||= PortfolioHistory.new(user: @user).months.to_h { |row| [ row[:month], row[:market_value_cents] ] }
  end

  def expense_by_category(month)
    category_totals.fetch(month, {})
      .sort_by { |category, cents| [ -cents, category.key ] }
      .map { |category, cents| { category_key: category.key, category_name: category.name, amount_cents: cents } }
  end

  def last_due_on
    return @last_due_on if defined?(@last_due_on)

    @last_due_on = [ @entries.maximum(:due_on), *@extra_entries.map(&:due_on) ].compact.max
  end

  def months_until_last_entry
    return 1 unless last_due_on && last_due_on >= @from

    span = (last_due_on.year - @from.year) * 12 + last_due_on.month - @from.month + 1
    [ span, ALL_MONTHS_LIMIT ].min
  end

  def opening_balance
    return 0 unless anchor

    last_day = @from.prev_day
    return anchor.amount_cents + net_between(anchor.as_of, last_day) if last_day >= anchor.as_of

    anchor.amount_cents - net_between(last_day, anchor.as_of)
  end

  def net_between(after, through)
    range = after.next_day..through
    @entries.where(due_on: range).sum(SIGNED_AMOUNT).to_i + @extra_entries.select { |entry| range.cover?(entry.due_on) }.sum { |entry| signed(entry) }
  end

  def signed(entry)
    entry.income? ? entry.amount_cents : -entry.amount_cents
  end

  def month_starts
    Array.new(@months) { |offset| @from >> offset }
  end

  def period
    @from..month_starts.last.end_of_month
  end

  def monthly_totals
    @monthly_totals ||= @entries
      .where(due_on: period)
      .group(MONTH_OF_DUE_ON, :kind, :nature)
      .sum(:amount_cents)
      .each_with_object(Hash.new { |hash, key| hash[key] = Hash.new(0) }) do |((month, kind, nature), cents), totals|
        totals[month][[ kind, nature ]] = cents
      end
      .tap { |totals| add_extra_entries(totals) }
  end

  def add_extra_entries(totals)
    extra_entries_in_period.each do |entry|
      totals[entry.due_on.beginning_of_month][[ entry.kind, entry.nature ]] += entry.amount_cents
    end
  end

  def category_totals
    @category_totals ||= @entries
      .expense
      .where(due_on: period)
      .group(MONTH_OF_DUE_ON, :category_id)
      .sum(:amount_cents)
      .each_with_object(Hash.new { |hash, key| hash[key] = Hash.new(0) }) do |((month, category_id), cents), totals|
        totals[month][categories_by_id.fetch(category_id)] += cents
      end
      .tap { |totals| add_extra_categories(totals) }
  end

  def categories_by_id
    @categories_by_id ||= Category.where(id: @entries.expense.where(due_on: period).select(:category_id)).index_by(&:id)
  end

  def add_extra_categories(totals)
    extra_entries_in_period.select(&:expense?).each do |entry|
      totals[entry.due_on.beginning_of_month][entry.category] += entry.amount_cents
    end
  end

  def extra_entries_in_period
    @extra_entries.select { |entry| period.cover?(entry.due_on) }
  end
end
