require "rails_helper"

RSpec.describe PortfolioHistory do
  let(:user) { create(:user) }
  let(:position) { create(:investment_position, user: user) }

  def buy(quantity, price_cents, on)
    create(:investment_transaction, user: user, position: position, quantity: quantity, price_cents: price_cents, traded_on: on)
  end

  it "is empty without transactions" do
    expect(described_class.new(user: user).months).to eq([])
  end

  it "values each month at the last close up to its end, or at cost without one" do
    buy(10, 1_000, Date.new(2026, 8, 20))
    buy(10, 1_200, Date.new(2026, 10, 5))
    create(:asset_quote, asset: position.asset, quoted_on: Date.new(2026, 9, 29), close_cents: 1_100)
    create(:asset_quote, asset: position.asset, quoted_on: Date.new(2026, 9, 30), close_cents: 1_150)
    create(:asset_quote, asset: position.asset, quoted_on: Date.new(2026, 11, 11), close_cents: 1_300)

    months = described_class.new(user: user, today: Date.new(2026, 11, 12)).months

    expect(months).to eq([
      { month: "2026-08", contributed_cents: 10_000, market_value_cents: 10_000 },
      { month: "2026-09", contributed_cents: 10_000, market_value_cents: 11_500 },
      { month: "2026-10", contributed_cents: 22_000, market_value_cents: 23_000 },
      { month: "2026-11", contributed_cents: 22_000, market_value_cents: 26_000 }
    ])
  end

  it "keeps the last 120 months" do
    buy(1, 1_000, Date.new(2010, 1, 1))

    months = described_class.new(user: user, today: Date.new(2026, 11, 12)).months

    expect(months.size).to eq(120)
    expect(months.first[:month]).to eq("2016-12")
  end
end
