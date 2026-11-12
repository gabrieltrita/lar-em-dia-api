require "rails_helper"

RSpec.describe ReserveSummary do
  let(:user) { create(:user) }
  let(:today) { Date.new(2026, 11, 12) }
  let(:housing) { create(:category, :expense, key: "housing", default_nature: :fixed) }

  def summary
    travel_to(today) { described_class.new(user.reload).to_h }
  end

  def fixed_expense(due_on, amount_cents)
    create(:entry, user: user, category: housing, nature: :fixed, due_on: due_on, amount_cents: amount_cents)
  end

  def reserve(amount_cents, kind: :selic_treasury)
    account = create(:reserve_account, user: user, kind: kind)
    create(:reserve_movement, user: user, account: account, kind: :anchor, moved_on: today, amount_cents: amount_cents)
  end

  it "has no suggestion and no alerts without fixed expenses or accounts" do
    expect(summary).to include(
      totals: { gross_cents: 0, net_cents: 0, invested_cents: 0, yield_cents: 0, tax_cents: 0 }, accounts: [], suggestion: nil,
      goal: { months: 6, cents: nil, target_cents: nil }, alerts: [], rates_as_of: nil
    )
  end

  it "suggests the goal months times the average fixed expenses of the last closed months" do
    fixed_expense(Date.new(2026, 7, 31), 999_999)
    fixed_expense(Date.new(2026, 9, 5), 300_000)
    fixed_expense(Date.new(2026, 10, 5), 200_000)
    fixed_expense(Date.new(2026, 10, 20), 100_000)
    fixed_expense(Date.new(2026, 11, 5), 999_999)
    create(:entry, user: user, category: housing, nature: :variable, due_on: Date.new(2026, 10, 5), amount_cents: 999_999)

    expect(summary).to include(
      suggestion: { average_fixed_cents: 300_000, months_counted: 2, goal_months: 6, suggested_cents: 1_800_000, coverage_months_e2: 0 },
      goal: { months: 6, cents: nil, target_cents: 1_800_000 }, alerts: [ "no_reserve" ]
    )
  end

  it "measures the coverage and warns below the target and about idle money" do
    fixed_expense(Date.new(2026, 10, 5), 300_000)
    reserve(900_000)
    reserve(360_000, kind: :idle)

    result = summary

    expect(result[:totals]).to include(gross_cents: 1_260_000, net_cents: 1_260_000)
    expect(result[:accounts].map { |account| account.slice(:kind, :gross_cents) }).to eq(
      [ { kind: "selic_treasury", gross_cents: 900_000 }, { kind: "idle", gross_cents: 360_000 } ]
    )
    expect(result[:suggestion]).to include(coverage_months_e2: 420)
    expect(result[:alerts]).to eq(%w[below_suggestion idle_money])
  end

  it "uses the goal the user set instead of the suggestion" do
    user.update!(reserve_goal_cents: 500_000, reserve_goal_months: 3)
    reserve(600_000)
    create(:interest_rate, rate_on: Date.new(2026, 11, 11))

    expect(summary).to include(goal: { months: 3, cents: 500_000, target_cents: 500_000 }, alerts: [], rates_as_of: Date.new(2026, 11, 11))
  end
end
