require "rails_helper"

RSpec.describe MarketData::B3Quotes do
  let(:date) { Date.new(2026, 11, 11) }

  it "reads the closing quotes of shares, units and FIIs from the daily COTAHIST file" do
    stub_b3_quotes

    quotes = described_class.fetch(date)

    expect(quotes.map(&:ticker)).to contain_exactly("BRSR6", "HGLG11", "B3SA3", "MXRF11", "TAEE11", "PETR4")
    expect(quotes.find { |quote| quote.ticker == "PETR4" }).to have_attributes(
      isin: "BRPETRACNPR6", name: "PETROBRAS", asset_type: :stock, quoted_on: date,
      close_cents: 4_355, volume_cents: 285_494_368_900, trades_count: 96_974
    )
    expect(quotes.find { |quote| quote.ticker == "HGLG11" }).to have_attributes(asset_type: :fii, isin: "BRHGLGCTF004", close_cents: 14_597)
  end

  it "returns nil when there is no file for the date" do
    stub_request(:get, "https://bvmf.bmfbovespa.com.br/InstDados/SerHist/COTAHIST_D15112026.ZIP").to_return(status: 404)

    expect(described_class.fetch(Date.new(2026, 11, 15))).to be_nil
  end
end
