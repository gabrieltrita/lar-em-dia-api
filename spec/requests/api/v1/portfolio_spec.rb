require "rails_helper"

RSpec.describe "Portfolio", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:position) { create(:investment_position, user: user, asset: create(:asset, ticker: "PETR4", name: "PETROBRAS")) }

  before do
    create(:investment_transaction, user: user, position: position, quantity: 100, price_cents: 3_000, traded_on: Date.new(2026, 10, 1))
    create(:asset_quote, asset: position.asset, quoted_on: Date.new(2026, 11, 11), close_cents: 3_300)
  end

  it "shows totals, goals and positions" do
    get "/api/v1/portfolio", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "totals")).to include("cost_cents" => 300_000, "market_value_cents" => 330_000, "gain_cents" => 30_000)
    expect(json.dig("data", "goals", "growth", "cost_cents")).to eq(300_000)
    expect(json.dig("data", "positions", 0)).to include(
      "ticker" => "PETR4", "name" => "PETROBRAS", "goal" => "growth", "quantity" => 100, "average_price_e8" => 3_000_000_000
    )
    expect(json.dig("data", "positions", 0, "quote")).to include("quoted_on" => "2026-11-11", "close_cents" => 3_300)
  end

  it "filters by goal and lists closed positions when asked" do
    hglg = create(:investment_position, user: user, asset: create(:asset, :fii, ticker: "HGLG11"))
    create(:investment_transaction, user: user, position: hglg, quantity: 1, traded_on: Date.new(2026, 10, 1))
    create(:investment_transaction, user: user, position: hglg, kind: :sell, quantity: 1, traded_on: Date.new(2026, 10, 2))

    get "/api/v1/portfolio", params: { goal: "income", include_closed: "true" }, headers: headers

    expect(json.dig("data", "positions", 0)).to include("ticker" => "HGLG11", "quantity" => 0, "quote" => nil)
  end

  it "shows the monthly history" do
    travel_to(Date.new(2026, 11, 12)) { get "/api/v1/portfolio/history", headers: headers }

    expect(response).to have_http_status(:ok)
    expect(json["data"].last).to eq("month" => "2026-11", "contributed_cents" => 300_000, "market_value_cents" => 330_000)
  end

  it "changes the goal of a position" do
    patch "/api/v1/investment_positions/petr4", params: { goal: "income" }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(json["data"]).to include("ticker" => "PETR4", "goal" => "income")

    put "/api/v1/investment_positions/PETR4", params: { goal: "growth" }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)

    patch "/api/v1/investment_positions/PETR4", params: { goal: "luck" }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)

    patch "/api/v1/investment_positions/VALE3", params: { goal: "income" }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
