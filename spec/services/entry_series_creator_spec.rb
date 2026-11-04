require "rails_helper"

RSpec.describe EntrySeriesCreator do
  let(:user) { create(:user) }
  let(:salary) { create(:category) }
  let(:attributes) { { category_id: salary.id, description: "Salary", amount_cents: 650_000, due_on: Date.new(2026, 11, 5) } }

  around { |example| travel_to(Date.new(2026, 11, 20)) { example.run } }

  def create_series(count: 3, direction: "forward", **overrides)
    creator = described_class.new(user: user, attributes: attributes.merge(overrides), count: count, direction: direction)
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
end
