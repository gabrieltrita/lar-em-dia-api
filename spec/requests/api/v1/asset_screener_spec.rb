require "rails_helper"

RSpec.describe "Asset screener", type: :request do
  let(:headers) { auth_headers(create(:user)) }
  let!(:high) { create(:asset_indicator, asset: create(:asset, :fii, ticker: "HGLG11"), dy_12m_bps: 900, p_vp_e2: 97, liquidity_cents: 5_000) }
  let!(:low) { create(:asset_indicator, asset: create(:asset, ticker: "PETR4"), dy_12m_bps: 300, p_vp_e2: 120, p_l_e2: 500) }
  let!(:empty) { create(:asset_indicator, asset: create(:asset, :fii, ticker: "BTLG11")) }
  let!(:unrefreshed) { create(:asset, ticker: "VALE3") }

  def tickers(**params)
    get "/api/v1/assets", params: params, headers: headers
    json["data"].pluck("ticker")
  end

  it "lists the indicators of every asset" do
    get "/api/v1/assets", params: { q: "HGLG" }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"].sole["indicators"]).to include("dy_12m_bps" => 900, "p_vp_e2" => 97, "p_l_e2" => nil, "computed_on" => "2026-11-11")
  end

  it "filters by indicator ranges, leaving out assets without the indicator" do
    expect(tickers(dy_12m_bps_min: "300", p_vp_e2_max: "100")).to eq(%w[HGLG11])
    expect(tickers(dy_12m_bps_min: "300", dy_12m_bps_max: "300")).to eq(%w[PETR4])
    expect(tickers(paying: "true", asset_type: "fii")).to eq(%w[HGLG11])
  end

  it "sorts by an indicator with the assets without it last, descending by default" do
    expect(tickers(sort: "dy_12m_bps")).to eq(%w[HGLG11 PETR4 BTLG11 VALE3])
    expect(tickers(sort: "dy_12m_bps", direction: "asc")).to eq(%w[PETR4 HGLG11 BTLG11 VALE3])
    expect(tickers(sort: "ticker", direction: "desc")).to eq(%w[VALE3 PETR4 HGLG11 BTLG11])
    expect(tickers(sort: "ticker")).to eq(%w[BTLG11 HGLG11 PETR4 VALE3])
  end

  it "rejects a filter that is not an integer" do
    get "/api/v1/assets", params: { p_l_e2_max: "5.5" }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(json["error"]["code"]).to eq("invalid_filter")
  end

  it "rejects an unknown sort or direction" do
    get "/api/v1/assets", params: { sort: "name" }, headers: headers
    expect(json["error"]["code"]).to eq("invalid_sort")

    get "/api/v1/assets", params: { sort: "dy_12m_bps", direction: "up" }, headers: headers
    expect(response).to have_http_status(:bad_request)
    expect(json["error"]["code"]).to eq("invalid_sort")
  end
end
