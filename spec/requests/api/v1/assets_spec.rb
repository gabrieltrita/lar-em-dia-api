require "rails_helper"

RSpec.describe "Assets", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it "requires authentication" do
    get "/api/v1/assets"

    expect(response).to have_http_status(:unauthorized)
  end

  it "lists the active assets by ticker, paginated" do
    create(:asset, ticker: "PETR4", name: "PETROBRAS", sector: "Petróleo e Gás")
    hglg = create(:asset, :fii, ticker: "HGLG11", name: "PÁTRIA LOG")
    create(:asset, :inactive, ticker: "OIBR3")

    get "/api/v1/assets", params: { limit: 1 }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"]).to eq([ { "ticker" => hglg.ticker, "name" => "PÁTRIA LOG", "asset_type" => "fii", "sector" => "Logística" } ])
    expect(json["meta"]).to include("total" => 2, "pages" => 2, "next" => 2)
  end

  it "filters by type, sector and search term, and ignores an unknown type" do
    petr = create(:asset, ticker: "PETR4", name: "PETROBRAS", sector: "Petróleo e Gás")
    create(:asset, ticker: "PRIO3", name: "PRIO", sector: "Petróleo e Gás")
    hglg = create(:asset, :fii, ticker: "HGLG11")

    get "/api/v1/assets", params: { asset_type: "fii" }, headers: headers
    expect(json["data"].pluck("ticker")).to eq([ hglg.ticker ])

    get "/api/v1/assets", params: { asset_type: "bdr", sector: "Petróleo e Gás", q: "petro" }, headers: headers
    expect(json["data"].pluck("ticker")).to eq([ petr.ticker ])
  end

  it "shows an asset by ticker, in any case, with its latest quote" do
    asset = create(:asset, ticker: "PETR4", isin: "BRPETRACNPR6", cnpj: "33000167000101")
    create(:asset_quote, asset: asset, quoted_on: Date.new(2026, 11, 10))
    create(:asset_quote, asset: asset, quoted_on: Date.new(2026, 11, 11), close_cents: 4_355)

    get "/api/v1/assets/petr4", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"]).to include("ticker" => "PETR4", "isin" => "BRPETRACNPR6", "cnpj" => "33000167000101", "active" => true)
    expect(json["data"]["quote"]).to eq(
      "quoted_on" => "2026-11-11", "close_cents" => 4_355, "volume_cents" => 285_494_368_900, "trades_count" => 96_974
    )
  end

  it "shows an inactive asset without quotes" do
    create(:asset, :inactive, ticker: "OIBR3")

    get "/api/v1/assets/OIBR3", headers: headers

    expect(json["data"]).to include("active" => false, "quote" => nil, "fund_report" => nil, "distributions" => [])
  end

  it "shows an FII's latest report and the distributions of the last 24 months, with the user's own records" do
    fund = create(:asset, :fii, ticker: "HGLG11")
    create(:fund_report, asset: fund, reference_month: Date.new(2026, 8, 1))
    create(:fund_report, asset: fund, reference_month: Date.new(2026, 9, 1), shareholders_count: 613_837)
    create(:asset_distribution, asset: fund, record_on: Date.new(2026, 9, 30), amount_per_share_e8: 116_691_920)
    create(:asset_distribution, asset: fund, record_on: Date.new(2024, 9, 30))
    stock = create(:asset, ticker: "PETR4")
    mine = create(:asset_distribution, :manual, user: user, asset: stock, kind: :jcp, record_on: Date.new(2026, 8, 20), amount_per_share_e8: 100_000_000)
    create(:asset_distribution, :manual, asset: stock)

    travel_to(Time.zone.local(2026, 11, 12, 12)) do
      get "/api/v1/assets/HGLG11", headers: headers
      expect(json.dig("data", "fund_report")).to include("reference_month" => "2026-09", "shareholders_count" => 613_837)
      expect(json.dig("data", "distributions")).to contain_exactly(
        a_hash_including("kind" => "fii_income", "source" => "cvm", "record_on" => "2026-09-30", "paid_on" => nil, "amount_per_share_e8" => 116_691_920)
      )

      get "/api/v1/assets/PETR4", headers: headers
    end

    expect(json.dig("data", "distributions")).to eq([ AssetDistributionBlueprint.render_as_hash(mine).as_json ])
    expect(json.dig("data", "distributions", 0, "net_amount_per_share_e8")).to eq(85_000_000)
  end

  it "answers 404 for an unknown ticker" do
    get "/api/v1/assets/XXXX3", headers: headers

    expect(response).to have_http_status(:not_found)
    expect(json["error"]["code"]).to eq("not_found")
  end
end
