require "rails_helper"

RSpec.describe AllocationPlan do
  let(:user) { create(:user) }
  let(:month) { Date.new(2026, 11, 1) }

  around { |example| travel_to(Date.new(2026, 11, 20)) { example.run } }

  before { create(:balance, user: user, as_of: Date.new(2026, 10, 31), amount_cents: 9_400) }

  def plan
    described_class.new(user: user, month: month).to_h
  end

  def amounts
    plan[:items].pluck(:name, :amount_cents)
  end

  it "splits the month's closing balance by fixed amounts, percentages and the remainder" do
    create(:allocation_target, :remainder, user: user)
    create(:allocation_target, :fixed, user: user, name: "Caridade")
    create(:allocation_target, user: user, name: "Investimentos", percent_bps: 2_000)

    expect(amounts).to eq([ [ "Reserva", 6_520 ], [ "Caridade", 1_000 ], [ "Investimentos", 1_880 ] ])
    expect(plan).to include(month: "2026-11", closing_cents: 9_400, base_cents: 9_400, used_cents: 0, planned_cents: 9_400, unallocated_cents: 0)
  end

  it "never plans more than the balance, in the targets' order" do
    create(:allocation_target, :fixed, user: user, name: "Viagem", amount_cents: 9_000)
    create(:allocation_target, user: user, name: "Investimentos", percent_bps: 2_000)
    create(:allocation_target, :remainder, user: user)

    expect(amounts).to eq([ [ "Viagem", 9_000 ], [ "Investimentos", 400 ], [ "Reserva", 0 ] ])
  end

  it "leaves what no target takes unallocated" do
    create(:allocation_target, user: user, percent_bps: 1_000)

    expect(plan).to include(planned_cents: 940, unallocated_cents: 8_460)
  end

  it "plans nothing when the month closes negative" do
    create(:entry, user: user, category: create(:category, :expense), amount_cents: 10_000, due_on: Date.new(2026, 11, 5))
    create(:allocation_target, user: user)
    create(:allocation_target, :remainder, user: user)

    expect(amounts.map(&:last)).to eq([ 0, 0 ])
    expect(plan).to include(base_cents: -600, unallocated_cents: -600)
  end

  it "keeps used amounts, adds them back to the base and plans the rest from what is left" do
    fixed = create(:allocation_target, :fixed, user: user, name: "Caridade", amount_cents: 1_000)
    create(:allocation_target, :remainder, user: user)
    entry = create(:entry, :paid, user: user, category: create(:category, :expense), amount_cents: 1_500, due_on: Date.new(2026, 11, 20))
    allocation = create(:allocation, user: user, target: fixed, month: month, entry: entry)

    expect(plan).to include(closing_cents: 7_900, base_cents: 9_400, used_cents: 1_500, planned_cents: 9_400)
    expect(plan[:items].first).to include(amount_cents: 1_500, used: true, allocation_id: allocation.id, used_on: "2026-11-20")
    expect(plan[:items].last).to include(amount_cents: 7_900, used: false, allocation_id: nil, used_on: nil)
  end

  it "answers the planned amount of one target" do
    target = create(:allocation_target, user: user, percent_bps: 5_000)

    expect(described_class.new(user: user, month: month).planned_cents_for(target)).to eq(4_700)
  end
end
