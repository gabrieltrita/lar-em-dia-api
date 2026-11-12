require "rails_helper"

RSpec.describe Portfolio do
  let(:user) { create(:user) }
  let(:petr) { create(:investment_position, user: user, asset: create(:asset, ticker: "PETR4")) }
  let(:hglg) { create(:investment_position, user: user, asset: create(:asset, :fii, ticker: "HGLG11")) }

  def trade(position, kind, quantity, price_cents, on = Date.new(2026, 10, 1))
    create(:investment_transaction, user: user, position: position, kind: kind, quantity: quantity, price_cents: price_cents, traded_on: on)
  end

  before do
    trade(petr, :buy, 100, 3_000)
    trade(petr, :sell, 20, 3_500, Date.new(2026, 10, 2))
    trade(hglg, :buy, 10, 15_000)
    create(:asset_quote, asset: petr.asset, quoted_on: Date.new(2026, 11, 10), close_cents: 3_200)
    create(:asset_quote, asset: petr.asset, quoted_on: Date.new(2026, 11, 11), close_cents: 3_300)
  end

  it "values each open position at the latest close, or at cost without a quote" do
    positions = described_class.new(user: user).positions.index_by { |item| item.position.ticker }

    expect(positions["PETR4"]).to have_attributes(market_value_cents: 264_000, gain_cents: 24_000)
    expect(positions["PETR4"].quote.close_cents).to eq(3_300)
    expect(positions["HGLG11"]).to have_attributes(quote: nil, market_value_cents: 150_000, gain_cents: 0)
  end

  it "sums the totals and splits them by goal" do
    portfolio = described_class.new(user: user)

    expect(portfolio.totals).to eq(contributed_cents: 380_000, cost_cents: 390_000, market_value_cents: 414_000, gain_cents: 24_000,
      realized_cents: 10_000)
    expect(portfolio.goals["income"]).to include(cost_cents: 150_000)
    expect(portfolio.goals["growth"]).to include(cost_cents: 240_000, realized_cents: 10_000)
  end

  it "filters by goal and hides closed positions unless asked" do
    trade(hglg, :sell, 10, 15_000, Date.new(2026, 10, 3))

    expect(described_class.new(user: user).positions.map { |item| item.position.ticker }).to eq([ "PETR4" ])
    expect(described_class.new(user: user, include_closed: true).positions.size).to eq(2)
    expect(described_class.new(user: user, goal: "income", include_closed: true).positions.map { |item| item.position.ticker }).to eq([ "HGLG11" ])
  end
end
