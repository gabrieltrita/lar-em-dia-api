require "rails_helper"

RSpec.describe "Assets", type: :request do
  let(:headers) { auth_headers(create(:user)) }

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

    expect(json["data"]).to include("active" => false, "quote" => nil)
  end

  it "answers 404 for an unknown ticker" do
    get "/api/v1/assets/XXXX3", headers: headers

    expect(response).to have_http_status(:not_found)
    expect(json["error"]["code"]).to eq("not_found")
  end
end
