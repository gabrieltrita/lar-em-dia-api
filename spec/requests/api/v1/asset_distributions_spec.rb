require "rails_helper"

RSpec.describe "Asset distributions", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:stock) { create(:asset, ticker: "PETR4") }
  let(:params) { { ticker: "petr4", kind: "jcp", record_on: "2026-08-20", paid_on: "2026-11-25", amount_per_share_e8: 33_333_333 } }

  before { create(:investment_position, user: user, asset: stock) }

  it "requires authentication" do
    get "/api/v1/asset_distributions"

    expect(response).to have_http_status(:unauthorized)
  end

  it "lists only the user's own records, newest first, filtered by ticker" do
    older = create(:asset_distribution, :manual, user: user, asset: stock, record_on: Date.new(2026, 5, 10))
    newer = create(:asset_distribution, :manual, user: user, asset: stock, record_on: Date.new(2026, 8, 20))
    create(:asset_distribution, :manual, user: user, asset: create(:asset, ticker: "VALE3"))
    create(:asset_distribution, :manual, asset: stock)
    create(:asset_distribution)

    get "/api/v1/asset_distributions", params: { ticker: "petr4" }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"].pluck("id")).to eq([ newer.id, older.id ])
    expect(json.dig("meta", "total")).to eq(2)

    get "/api/v1/asset_distributions", headers: headers
    expect(json["data"].size).to eq(3)
  end

  it "records a JCP of a stock in the portfolio" do
    post "/api/v1/asset_distributions", params: params, headers: headers, as: :json

    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("ticker" => "PETR4", "kind" => "jcp", "source" => "manual", "paid_on" => "2026-11-25",
      "amount_per_share_e8" => 33_333_333, "net_amount_per_share_e8" => 28_333_333)
    expect(user.asset_distributions.sole.asset).to eq(stock)
  end

  it "refuses a ticker outside the portfolio, an FII and invalid dates" do
    post "/api/v1/asset_distributions", params: params.merge(ticker: "XXXX3", paid_on: "2026-08-01"), headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "ticker", 0, "code")).to eq("unknown_asset")
    expect(json.dig("error", "details", "paid_on", 0, "code")).to eq("before_record_on")
  end

  it "updates a record but not its ticker" do
    distribution = create(:asset_distribution, :manual, user: user, asset: stock)

    patch "/api/v1/asset_distributions/#{distribution.id}", params: { amount_per_share_e8: 50_000_000, ticker: "PETR4" }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "amount_per_share_e8")).to eq(50_000_000)

    put "/api/v1/asset_distributions/#{distribution.id}", params: { kind: "dividend" }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)

    patch "/api/v1/asset_distributions/#{distribution.id}", params: { ticker: "VALE3" }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "ticker", 0, "code")).to eq("immutable")

    patch "/api/v1/asset_distributions/#{distribution.id}", params: { amount_per_share_e8: 0 }, headers: headers, as: :json
    expect(json.dig("error", "details", "amount_per_share_e8", 0, "code")).to eq("greater_than")
  end

  it "deletes a record" do
    distribution = create(:asset_distribution, :manual, user: user, asset: stock)

    delete "/api/v1/asset_distributions/#{distribution.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "deleted_id")).to eq(distribution.id)
    expect(AssetDistribution.exists?(distribution.id)).to be(false)
  end

  it "answers 404 for another user's record and for CVM records" do
    other = create(:asset_distribution, :manual)
    cvm = create(:asset_distribution)

    patch "/api/v1/asset_distributions/#{other.id}", params: { kind: "dividend" }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/asset_distributions/#{cvm.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
