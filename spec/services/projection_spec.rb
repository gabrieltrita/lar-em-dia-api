require "rails_helper"

RSpec.describe Projection do
  let(:user) { create(:user) }
  let(:salary) { create(:category) }
  let(:rent) { create(:category, :expense, default_nature: :fixed) }
  let(:groceries) { create(:category, :expense, default_nature: :variable) }

  def projection(from, months)
    described_class.new(user: user, from: Date.iso8601(from), months: months).months
  end

  def closings(rows)
    rows.map { |row| [ row[:month], row[:opening_cents], row[:closing_cents] ] }
  end

  around { |example| travel_to(Date.new(2026, 12, 31)) { example.run } }

  before do
    create(:entry, user: user, category: salary, amount_cents: 20_000, due_on: "2026-10-15")
    create(:entry, :paid, user: user, category: salary, amount_cents: 50_000, due_on: "2026-11-05")
    create(:entry, user: user, category: rent, amount_cents: 30_000, due_on: "2026-11-20")
    create(:entry, user: user, category: groceries, amount_cents: 10_000, due_on: "2026-12-05")
    create(:entry, category: salary, amount_cents: 999_999, due_on: "2026-11-05")
  end

  context "with a balance" do
    before do
      create(:balance, user: user, amount_cents: 1_000, as_of: "2026-09-01")
      create(:balance, user: user, amount_cents: 100_000, as_of: "2026-11-10")
    end

    it "anchors on the most recent balance" do
      anchor = described_class.new(user: user, from: Date.current).anchor

      expect(anchor).to have_attributes(amount_cents: 100_000, as_of: Date.new(2026, 11, 10))
    end

    it "works backwards for months before the anchor and forwards after it" do
      rows = projection("2026-10-01", 3)

      expect(closings(rows)).to eq([ [ "2026-10", 30_000, 50_000 ], [ "2026-11", 50_000, 70_000 ], [ "2026-12", 70_000, 60_000 ] ])
    end

    it "splits income and fixed and variable expenses" do
      november, december = projection("2026-11-01", 2)

      expect(november).to include(income_cents: 50_000, expense_cents: 30_000, fixed_expense_cents: 30_000, variable_expense_cents: 0)
      expect(december).to include(income_cents: 0, expense_cents: 10_000, fixed_expense_cents: 0, variable_expense_cents: 10_000)
    end

    it "starts after the anchor from the balance carried forward" do
      expect(closings(projection("2026-12-20", 2))).to eq([ [ "2026-12", 70_000, 60_000 ], [ "2027-01", 60_000, 60_000 ] ])
    end
  end

  it "starts from zero without a balance" do
    expect(closings(projection("2026-11-01", 2))).to eq([ [ "2026-11", 0, 20_000 ], [ "2026-12", 20_000, 10_000 ] ])
  end

  it "accumulates savings from the first projected month" do
    rows = projection("2026-11-01", 3)

    expect(rows.pluck(:savings_cents)).to eq([ 20_000, 10_000, 10_000 ])
  end

  it "projects twelve months by default" do
    rows = described_class.new(user: user, from: Date.new(2026, 11, 1)).months

    expect(rows.pluck(:month)).to eq(%w[2026-11 2026-12] + (1..10).map { |month| format("2027-%02d", month) })
  end
end
