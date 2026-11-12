require "rails_helper"

RSpec.describe MarketData::Backfill do
  let(:october) { "https://bvmf.bmfbovespa.com.br/InstDados/SerHist/COTAHIST_M102026.ZIP" }
  let(:september) { "https://bvmf.bmfbovespa.com.br/InstDados/SerHist/COTAHIST_M092026.ZIP" }

  before do
    stub_market_data(october, "COTAHIST_M102026.ZIP")
    stub_market_data(september, status: 404)
  end

  it "keeps the last quote of each month and creates missing assets as inactive" do
    petr = create(:asset, ticker: "PETR4", isin: "BRPETRACNPR6")

    result = described_class.call(from: Date.new(2026, 9, 1), to: Date.new(2026, 10, 15))

    expect(result).to have_attributes(months: 2, assets_created: 1, quotes_saved: 2)
    expect(petr.reload.active).to be(true)
    expect(petr.quotes.sole).to have_attributes(quoted_on: Date.new(2026, 10, 30), close_cents: 5_271)
    expect(Asset.find_by!(ticker: "HGLG11")).to have_attributes(active: false, asset_type: "fii", isin: "BRHGLGCTF004")
  end

  it "does not duplicate anything when it runs again" do
    described_class.call(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 1))

    expect(described_class.call(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 1)))
      .to have_attributes(assets_created: 0, quotes_saved: 0)
    expect(AssetQuote.count).to eq(2)
  end
end
