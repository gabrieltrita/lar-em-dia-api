require "rails_helper"

RSpec.describe Allocation do
  it "keeps the first day of the month" do
    allocation = build(:allocation, month: Date.new(2026, 10, 17))

    expect(allocation.month).to eq(Date.new(2026, 10, 1))
  end

  it "uses today in the current month and the last day in past months" do
    travel_to Date.new(2026, 11, 20) do
      expect(build(:allocation, month: Date.new(2026, 11, 1)).used_on).to eq(Date.new(2026, 11, 20))
      expect(build(:allocation, month: Date.new(2026, 9, 1)).used_on).to eq(Date.new(2026, 9, 30))
    end
  end

  it "refuses future months, a missing month and a second use in the same month" do
    existing = create(:allocation)

    future = build(:allocation, month: Date.current.next_month)
    missing = build(:allocation, month: nil)
    repeated = build(:allocation, user: existing.user, target: existing.target)

    expect(future).not_to be_valid
    expect(future.errors.details[:month].pluck(:error)).to eq([ :in_future ])
    expect(missing).not_to be_valid
    expect(missing.errors.details[:month].pluck(:error)).to eq([ :blank ])
    expect(repeated).not_to be_valid
    expect(repeated.errors.details[:month].pluck(:error)).to eq([ :taken ])
  end

  it "requires a positive amount when created" do
    allocation = build(:allocation, amount_cents: 0)

    expect(allocation).not_to be_valid
    expect(allocation.errors.details[:amount_cents].pluck(:error)).to eq([ :greater_than ])
  end

  it "disappears with its entry" do
    allocation = create(:allocation)

    allocation.entry.destroy!

    expect(described_class.exists?(allocation.id)).to be(false)
  end
end
