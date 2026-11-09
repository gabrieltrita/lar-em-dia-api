require "rails_helper"

RSpec.describe EntrySeriesCreator do
  let(:user) { create(:user) }
  let(:salary) { create(:category) }
  let(:attributes) { { category_id: salary.id, description: "Salary", amount_cents: 650_000, due_on: Date.new(2026, 11, 5) } }

  around { |example| travel_to(Date.new(2026, 11, 20)) { example.run } }

  def create_series(count: 3, direction: "forward", kind: nil, total_cents: nil, interval_months: nil, **overrides)
    creator = described_class.new(user: user, attributes: attributes.merge(overrides), count: count, direction: direction, kind: kind, total_cents: total_cents,
                                  interval_months: interval_months)
    [ creator.call, creator.series ]
  end

  it "creates one entry per following month in position order" do
    created, series = create_series

    expect(created).to be(true)
    expect(series.reload.entries.map { |entry| [ entry.due_on.iso8601, entry.series_position ] }).to eq(
      [ [ "2026-11-05", 1 ], [ "2026-12-05", 2 ], [ "2027-01-05", 3 ] ]
    )
    expect(series.entries.map(&:user).uniq).to eq([ user ])
    expect(series).to have_attributes(kind: "recurring", entries_count: 3)
  end

  it "goes backwards with the sent entry last" do
    _, series = create_series(direction: "backward")

    expect(series.entries.map { |entry| entry.due_on.iso8601 }).to eq(%w[2026-09-05 2026-10-05 2026-11-05])
  end

  it "uses the last day of shorter months without shrinking the day" do
    _, series = create_series(due_on: Date.new(2027, 1, 31))

    expect(series.entries.map { |entry| entry.due_on.iso8601 }).to eq(%w[2027-01-31 2027-02-28 2027-03-31])
  end

  it "repeats every few months on the same day" do
    _, series = create_series(interval_months: 6)

    expect(series.reload.interval_months).to eq(6)
    expect(series.entries.map { |entry| entry.due_on.iso8601 }).to eq(%w[2026-11-05 2027-05-05 2027-11-05])
  end

  it "repeats yearly backwards, using the last day of February outside leap years" do
    _, series = create_series(interval_months: 12, direction: "backward", due_on: Date.new(2028, 2, 29))

    expect(series.entries.map { |entry| entry.due_on.iso8601 }).to eq(%w[2026-02-28 2027-02-28 2028-02-29])
  end

  it "refuses an interval outside the list" do
    created, series = create_series(interval_months: 2)

    expect(created).to be(false)
    expect(series.errors.details[:interval_months]).to eq([ { error: :inclusion, value: 2 } ])
  end

  it "marks the copies due up to today as paid on their due dates and the later ones as pending" do
    _, series = create_series(status: "paid", paid_on: Date.new(2026, 10, 6), due_on: Date.new(2026, 10, 5))

    expect(series.entries.map { |entry| [ entry.status, entry.paid_on&.iso8601 ] }).to eq(
      [ [ "paid", "2026-10-06" ], [ "paid", "2026-11-05" ], [ "pending", nil ] ]
    )
  end

  it "keeps the copies pending when the sent entry is pending" do
    _, series = create_series(direction: "backward")

    expect(series.entries.map(&:status).uniq).to eq([ "pending" ])
  end

  it "builds the entries in memory without saving them" do
    creator = described_class.new(user: user, attributes: attributes, count: 2, direction: "forward")
    entries = creator.build

    expect(entries.map(&:due_on)).to eq([ attributes[:due_on].to_date, attributes[:due_on].to_date >> 1 ])
    expect(entries).to all(be_new_record)
    expect(Entry.count).to eq(0)
  end

  it "creates nothing and gathers the series and entry errors when invalid" do
    created, series = create_series(count: 37, direction: "sideways", amount_cents: 0)

    expect(created).to be(false)
    expect(series.errors.details.keys).to contain_exactly(:entries_count, :direction, :amount_cents)
    expect(Entry.count + EntrySeries.count).to eq(0)
  end

  it "reports only the entry errors when the series is valid" do
    created, series = create_series(description: "")

    expect(created).to be(false)
    expect(series.errors.details.keys).to eq([ :description ])
  end

  context "with installments" do
    let(:card) { create(:category, :expense) }
    let(:attributes) { { category_id: card.id, description: "Sofa", amount_cents: 1, due_on: Date.new(2026, 11, 10) } }

    it "splits the total monthly forwards whatever the direction and interval" do
      created, series = create_series(kind: "installments", total_cents: 100_000, direction: "backward", interval_months: 12)

      expect(created).to be(true)
      expect(series.reload).to have_attributes(kind: "installments", total_cents: 100_000, entries_count: 3, interval_months: 1)
      expect(series.entries.map { |entry| [ entry.due_on.iso8601, entry.amount_cents ] }).to eq(
        [ [ "2026-11-10", 33_334 ], [ "2026-12-10", 33_333 ], [ "2027-01-10", 33_333 ] ]
      )
    end

    it "accepts up to 48 installments" do
      created, series = create_series(kind: "installments", total_cents: 4_800, count: 48)

      expect(created).to be(true)
      expect(series.entries.size).to eq(48)
    end

    it "reports the total instead of the amount when the total is missing" do
      created, series = create_series(kind: "installments", total_cents: nil)

      expect(created).to be(false)
      expect(series.errors.details.keys).to eq([ :total_cents ])
    end

    it "refuses income installments" do
      created, series = create_series(kind: "installments", total_cents: 9_000, category_id: create(:category).id)

      expect(created).to be(false)
      expect(series.errors.details[:kind]).to eq([ { error: :only_for_expenses } ])
    end

    it "keeps the entry errors other than the amount" do
      created, series = create_series(kind: "installments", total_cents: nil, description: "")

      expect(created).to be(false)
      expect(series.errors.details.keys).to contain_exactly(:total_cents, :description)
    end
  end
end
