require "rails_helper"

RSpec.describe DistributionIncome do
  subject(:income) { described_class.new(user: user, today: Date.new(2026, 11, 12)) }

  let(:user) { create(:user) }
  let(:fund) { create(:asset, :fii, ticker: "HGLG11") }
  let(:stock) { create(:asset, ticker: "PETR4") }

  def buy(asset, quantity, traded_on)
    position = user.investment_positions.find_or_create_by!(asset: asset)
    create(:investment_transaction, user: user, position: position, quantity: quantity, traded_on: traded_on)
  end

  before do
    buy(fund, 100, Date.new(2026, 1, 10))
    buy(fund, 50, Date.new(2026, 6, 15))
    buy(stock, 200, Date.new(2026, 3, 1))
    (1..9).each { |month| create(:asset_distribution, asset: fund, record_on: Date.new(2026, month, 1).end_of_month, amount_per_share_e8: 110_000_000) }
    create(:asset_distribution, asset: fund, record_on: Date.new(2025, 6, 30), amount_per_share_e8: 999_000_000)
    create(:asset_distribution, :manual, user: user, asset: stock, kind: :jcp, record_on: Date.new(2026, 8, 20), paid_on: Date.new(2026, 11, 25),
      amount_per_share_e8: 33_333_333)
    create(:asset_distribution, :manual, user: user, asset: stock, record_on: Date.new(2026, 11, 10), paid_on: Date.new(2027, 1, 15),
      amount_per_share_e8: 100_000_000)
    create(:asset_distribution, :manual, asset: stock, record_on: Date.new(2026, 8, 20), paid_on: Date.new(2026, 9, 1), amount_per_share_e8: 500_000_000)
  end

  it "counts each payment month of the last 12 for the shares held on the record date, with JCP net of tax" do
    received = income.received.to_h { |row| [ row[:month], row[:amount_cents] ] }

    expect(received.keys).to eq((0..11).map { |offset| (Date.new(2025, 12, 1) >> offset).strftime("%Y-%m") })
    expect(received.values_at("2025-12", "2026-01", "2026-02", "2026-06", "2026-07", "2026-10", "2026-11")).to eq([ 0, 0, 11_000, 11_000, 16_500, 16_500, 5_667 ])
  end

  it "forecasts the months after the current one with the announced distributions or the 12-month average per share" do
    expect(income.forecast(3)).to eq([
      { month: "2026-12", amount_cents: 12_847 },
      { month: "2027-01", amount_cents: 32_375 },
      { month: "2027-02", amount_cents: 12_847 }
    ])
    expect(income.forecast.size).to eq(12)
    expect(income.forecast_cents(Date.new(2026, 11, 1))).to eq(0)
  end

  it "summarizes the monthly average and each position" do
    expect(income.monthly_average_cents).to eq(10_556)
    expect(income.positions).to eq([
      { ticker: "HGLG11", goal: "income", quantity: 150, received_12m_cents: 121_000, monthly_forecast_cents: 12_375 },
      { ticker: "PETR4", goal: "growth", quantity: 200, received_12m_cents: 5_667, monthly_forecast_cents: 472 }
    ])
  end

  it "is zero without positions" do
    other = described_class.new(user: create(:user), today: Date.new(2026, 11, 12))

    expect(other.monthly_average_cents).to eq(0)
    expect(other.forecast(1)).to eq([ { month: "2026-12", amount_cents: 0 } ])
    expect(other.positions).to eq([])
  end
end
