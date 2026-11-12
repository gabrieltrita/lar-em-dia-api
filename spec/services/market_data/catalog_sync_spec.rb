require "rails_helper"

RSpec.describe MarketData::CatalogSync do
  let(:date) { Date.new(2026, 11, 11) }

  def quote(ticker, **attributes)
    MarketData::B3Quotes::Quote.new(
      ticker: ticker, isin: "BR#{ticker.ljust(9, 'X')[0, 9]}1", name: ticker, asset_type: :stock, quoted_on: date,
      close_cents: 1_000, volume_cents: 50_000, trades_count: 10, **attributes
    )
  end

  it "creates the assets and their quotes and counts what it saved" do
    result = described_class.call([ quote("PETR4"), quote("HGLG11", asset_type: :fii), quote("BAD"), quote("ZERO3", close_cents: 0) ])

    expect(result).to have_attributes(quotes_received: 4, quotes_saved: 2, deactivated: 0, funds_matched: 0, companies_matched: 0)
    expect(Asset.find_by!(ticker: "HGLG11")).to have_attributes(asset_type: "fii", active: true, name: "HGLG11")
    expect(Asset.find_by!(ticker: "PETR4").latest_quote).to have_attributes(quoted_on: date, close_cents: 1_000, trades_count: 10)
  end

  it "updates the quote of the same day and keeps the name taken from the CVM" do
    asset = create(:asset, ticker: "PETR4", name: "PETROLEO BRASILEIRO S.A. PETROBRAS")
    create(:asset_quote, asset: asset, quoted_on: date, close_cents: 900)

    described_class.call([ quote("PETR4", close_cents: 1_100) ])

    expect(asset.reload.name).to eq("PETROLEO BRASILEIRO S.A. PETROBRAS")
    expect(asset.quotes.sole.close_cents).to eq(1_100)
  end

  it "deactivates assets without quotes in the last 30 days and reactivates the ones that trade again" do
    stale = create(:asset)
    create(:asset_quote, asset: stale, quoted_on: date - 31)
    recent = create(:asset)
    create(:asset_quote, asset: recent, quoted_on: date - 30)
    returning = create(:asset, :inactive, ticker: "PETR4")

    result = described_class.call([ quote("PETR4") ])

    expect(result.deactivated).to eq(1)
    expect([ stale, recent, returning ].map { |asset| asset.reload.active }).to eq([ false, true, true ])
  end

  it "changes nothing when no quote is valid" do
    asset = create(:asset)

    expect(described_class.call([ quote("BAD") ])).to have_attributes(quotes_saved: 0, deactivated: 0)
    expect(asset.reload.active).to be(true)
  end

  it "enriches FIIs by ISIN and stocks by ticker with the CVM registry" do
    fii = create(:asset, :fii, isin: "BRHGLGCTF004", sector: nil)
    stock = create(:asset, ticker: "PETR4")
    untouched = create(:asset, ticker: "VALE3")
    funds = [ MarketData::CvmFunds::Fund.new(isin: "BRHGLGCTF004", cnpj: "11728688000147", name: "PÁTRIA LOG", sector: "Logística") ]
    companies = [
      MarketData::CvmCompanies::Company.new(ticker: "PETR4", cnpj: "33000167000101", name: "PETROBRAS", sector: "Petróleo e Gás"),
      MarketData::CvmCompanies::Company.new(ticker: "ITUB4", cnpj: "60872504000123", name: "ITAU UNIBANCO", sector: "Bancos")
    ]

    result = described_class.call([], funds: funds, companies: companies)

    expect(result).to have_attributes(funds_matched: 1, companies_matched: 1)
    expect(fii.reload).to have_attributes(cnpj: "11728688000147", name: "PÁTRIA LOG", sector: "Logística")
    expect(stock.reload).to have_attributes(cnpj: "33000167000101", name: "PETROBRAS", sector: "Petróleo e Gás")
    expect(untouched.reload.cnpj).to be_nil
    expect(Asset.exists?(ticker: "ITUB4")).to be(false)
  end
end
