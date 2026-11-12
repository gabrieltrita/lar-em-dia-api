require "rails_helper"

RSpec.describe PositionLedger do
  def transaction(kind, quantity, on, price_cents: nil, fees_cents: 0)
    build(:investment_transaction, kind: kind, quantity: quantity, traded_on: Date.new(2026, 1, 1) + on, price_cents: price_cents,
      fees_cents: fees_cents)
  end

  it "is empty without transactions" do
    expect(described_class.new([]).state).to have_attributes(quantity: 0, cost_cents: 0, average_price_e8: 0)
  end

  it "weights the average price with fees and keeps it on sales" do
    ledger = described_class.new([
      transaction(:sell, 50, 3, price_cents: 1_500, fees_cents: 100),
      transaction(:buy, 100, 1, price_cents: 1_000, fees_cents: 500),
      transaction(:buy, 100, 2, price_cents: 1_200)
    ])

    expect(ledger.state).to have_attributes(
      quantity: 150, cost_cents: 165_375, contributed_cents: 145_600, realized_cents: 19_775, average_price_e8: 1_102_500_000
    )
  end

  it "resets the cost when everything is sold" do
    ledger = described_class.new([ transaction(:buy, 3, 1, price_cents: 1_000), transaction(:sell, 3, 2, price_cents: 900) ])

    expect(ledger.state).to have_attributes(quantity: 0, cost_cents: 0, realized_cents: -300, average_price_e8: 0)
  end

  it "changes the shares but not the cost on splits, reverse splits and bonuses" do
    ledger = described_class.new([
      transaction(:buy, 100, 1, price_cents: 1_000),
      transaction(:split, 100, 2),
      transaction(:bonus, 20, 3),
      transaction(:reverse_split, 110, 4)
    ])

    expect(ledger.state).to have_attributes(quantity: 110, cost_cents: 100_000, average_price_e8: 909_090_909)
  end

  it "drops the cost when a reverse split leaves no shares" do
    ledger = described_class.new([ transaction(:buy, 1, 1, price_cents: 1_000), transaction(:reverse_split, 1, 2) ])

    expect(ledger.state).to have_attributes(quantity: 0, cost_cents: 0)
  end

  it "detects a day when the position would go below zero" do
    covered = described_class.new([ transaction(:buy, 10, 1, price_cents: 100), transaction(:sell, 10, 2, price_cents: 100) ])
    uncovered = described_class.new([ transaction(:buy, 10, 2, price_cents: 100), transaction(:sell, 10, 1, price_cents: 100) ])

    expect(covered).not_to be_shortfall
    expect(uncovered).to be_shortfall
    expect(uncovered.state.quantity).to eq(0)
  end

  it "orders same-day transactions by creation and gives the state at each date, in ascending order" do
    buy = transaction(:buy, 10, 1, price_cents: 100)
    sell = transaction(:sell, 10, 1, price_cents: 100)
    buy.created_at = 1.minute.ago
    ledger = described_class.new([ sell, buy, transaction(:buy, 5, 10, price_cents: 100) ])

    expect(ledger).not_to be_shortfall
    expect(ledger.states_on([ Date.new(2025, 12, 31), Date.new(2026, 1, 5), Date.new(2026, 1, 20) ]).map(&:quantity)).to eq([ 0, 0, 5 ])
  end
end
