require "rails_helper"

RSpec.describe Projection do
  let(:user) { create(:user) }
  let(:salary) { create(:category) }
  let(:rent) { create(:category, :expense, key: "rent", name: "Rent", default_nature: :fixed) }
  let(:groceries) { create(:category, :expense, key: "food", name: "Food", default_nature: :variable) }

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

  it "flags the months that close below zero" do
    create(:entry, user: user, category: rent, amount_cents: 50_000, due_on: "2027-01-10")
    projection = described_class.new(user: user, from: Date.new(2026, 11, 1), months: 4)

    expect(projection.months.pluck(:negative)).to eq([ false, false, true, true ])
    expect(projection.alerts).to eq(first_negative_month: "2027-01", negative_months_count: 2)
  end

  it "has no alert when every month stays positive" do
    expect(described_class.new(user: user, from: Date.new(2026, 11, 1), months: 2).alerts)
      .to eq(first_negative_month: nil, negative_months_count: 0)
  end

  it "projects twelve months by default" do
    rows = described_class.new(user: user, from: Date.new(2026, 11, 1)).months

    expect(rows.pluck(:month)).to eq(%w[2026-11 2026-12] + (1..10).map { |month| format("2027-%02d", month) })
  end

  it "sums the expenses of each month by category, largest first" do
    create(:entry, user: user, category: groceries, amount_cents: 40_000, due_on: "2026-11-25")
    create(:entry, user: user, category: groceries, amount_cents: 5_000, due_on: "2026-11-26")
    create(:entry, category: groceries, amount_cents: 999_999, due_on: "2026-11-26")

    october, november, december = projection("2026-10-01", 3)

    expect(october[:expense_by_category]).to eq([])
    expect(november[:expense_by_category]).to eq([ { category_key: "food", category_name: "Food", amount_cents: 45_000 }, { category_key: "rent", category_name: "Rent", amount_cents: 30_000 } ])
    expect(december[:expense_by_category]).to eq([ { category_key: "food", category_name: "Food", amount_cents: 10_000 } ])
  end

  it "breaks ties between categories by key" do
    create(:entry, user: user, category: groceries, amount_cents: 30_000, due_on: "2026-11-25")

    expect(projection("2026-11-01", 1).first[:expense_by_category].pluck(:category_key)).to eq(%w[food rent])
  end

  it "names the user's own categories" do
    pet = create(:category, :expense, user: user, name: "Pet")
    create(:entry, user: user, category: pet, amount_cents: 50_000, due_on: "2026-11-25")

    expect(projection("2026-11-01", 1).first[:expense_by_category].first).to eq(category_key: pet.key, category_name: "Pet", amount_cents: 50_000)
  end

  it "adds the expenses of extra entries to their categories" do
    extra = [
      user.entries.new(category: groceries, description: "TV", amount_cents: 7_000, due_on: Date.new(2026, 11, 2)),
      user.entries.new(category: salary, description: "Bonus", amount_cents: 1_000, due_on: Date.new(2026, 11, 3)),
      user.entries.new(category: groceries, description: "Later", amount_cents: 1_000, due_on: Date.new(2027, 5, 3))
    ].each(&:validate)
    rows = described_class.new(user: user, from: Date.new(2026, 11, 1), months: 1, extra_entries: extra).months

    expect(rows.first[:expense_by_category]).to eq([ { category_key: "rent", category_name: "Rent", amount_cents: 30_000 }, { category_key: "food", category_name: "Food", amount_cents: 7_000 } ])
  end

  describe "through the last entry" do
    def all_months(from, extra_entries: [])
      described_class.new(user: user, from: Date.iso8601(from), months: :all, extra_entries: extra_entries)
    end

    it "projects through the month of the latest due date" do
      create(:entry, user: user, category: rent, amount_cents: 1_000, due_on: "2027-03-10")
      projection = all_months("2026-11-01")

      expect(projection.months.pluck(:month)).to eq(%w[2026-11 2026-12 2027-01 2027-02 2027-03])
      expect(projection.last_entry_month).to eq("2027-03")
    end

    it "counts the extra entries" do
      extra = [ user.entries.new(category: groceries, description: "Trip", amount_cents: 1_000, due_on: Date.new(2027, 2, 1)) ]
      projection = all_months("2026-12-01", extra_entries: extra)

      expect(projection.months.size).to eq(3)
      expect(projection.last_entry_month).to eq("2027-02")
    end

    it "projects one month when every entry is earlier" do
      projection = all_months("2027-06-01")

      expect(projection.months.pluck(:month)).to eq(%w[2027-06])
      expect(projection.last_entry_month).to eq("2026-12")
    end

    it "stops at sixty months" do
      create(:entry, user: user, category: rent, amount_cents: 1_000, due_on: "2035-01-10")

      expect(all_months("2026-11-01").months.size).to eq(described_class::ALL_MONTHS_LIMIT)
    end

    it "projects one month and has no last entry month without entries" do
      projection = described_class.new(user: create(:user), from: Date.new(2026, 11, 1), months: :all)

      expect(projection.months.size).to eq(1)
      expect(projection.last_entry_month).to be_nil
    end
  end
end
