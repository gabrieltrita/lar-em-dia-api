require "rails_helper"

RSpec.describe "Portfolio simulation", type: :request do
  let(:headers) { auth_headers(create(:user)) }
  let(:fund) { create(:asset, :fii, ticker: "HGLG11") }

  def simulate(**body)
    post "/api/v1/portfolio/simulation", params: body, headers: headers, as: :json
  end

  it "requires authentication" do
    post "/api/v1/portfolio/simulation", params: { kind: "growth" }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "simulates an FII's income buying whole shares and reinvesting, and finds the target" do
    create(:asset_indicator, asset: fund, price_cents: 10_000, distribution_average_e8: 100_000_000)

    simulate(kind: "income", ticker: "hglg11", initial_cents: 100_000, monthly_cents: 15_000, months: 3, target_monthly_income_cents: 12)

    expect(response).to have_http_status(:ok)
    expect(json["data"]).to include("kind" => "income", "ticker" => "HGLG11", "price_cents" => 10_000, "monthly_income_per_share_e8" => 100_000_000,
      "monthly_yield_bps" => nil, "reinvest" => true)
    expect(json["data"]["months"]).to eq([
      { "month" => 1, "contributed_cents" => 115_000, "shares" => 11, "value_cents" => 116_100, "income_cents" => 1_100, "received_cents" => 1_100 },
      { "month" => 2, "contributed_cents" => 130_000, "shares" => 13, "value_cents" => 132_400, "income_cents" => 1_300, "received_cents" => 2_400 },
      { "month" => 3, "contributed_cents" => 145_000, "shares" => 14, "value_cents" => 148_800, "income_cents" => 1_400, "received_cents" => 3_800 }
    ])
    expect(json["data"]["summary"]).to eq("contributed_cents" => 145_000, "value_cents" => 148_800, "monthly_income_cents" => 1_400,
      "received_cents" => 3_800, "target_monthly_income_cents" => 12, "shares_for_target" => 1, "capital_for_target_cents" => 10_000,
      "months_to_target" => 1)
  end

  it "simulates a stock's income from its dividend yield without reinvesting" do
    stock = create(:asset, ticker: "PETR4")
    create(:asset_indicator, asset: stock, price_cents: 3_000, dy_12m_bps: 1_200)

    simulate(kind: "income", ticker: "PETR4", initial_cents: 30_000, months: 2, reinvest: false, target_monthly_income_cents: 1_000_000)

    expect(json["data"]).to include("monthly_income_per_share_e8" => 30_000_000)
    expect(json["data"]["months"].pluck("shares", "income_cents", "value_cents")).to eq([ [ 10, 300, 30_000 ], [ 10, 300, 30_000 ] ])
    expect(json["data"]["summary"]).to include("shares_for_target" => 33_334, "months_to_target" => nil)
  end

  it "simulates income from a monthly yield without an asset" do
    simulate(kind: "income", monthly_yield_bps: 100, initial_cents: 100_000, months: 1)

    expect(json["data"]).to include("ticker" => nil, "price_cents" => nil, "monthly_yield_bps" => 100)
    expect(json["data"]["months"].sole).to include("shares" => nil, "income_cents" => 1_000, "value_cents" => 101_000)
    expect(json["data"]["summary"]).to include("target_monthly_income_cents" => nil, "shares_for_target" => nil, "capital_for_target_cents" => nil)
  end

  it "compounds contributions at the user's annual rate" do
    simulate(kind: "growth", initial_cents: 100_000, monthly_cents: 10_000, months: 12, annual_rate_bps: 1_200)

    expect(response).to have_http_status(:ok)
    expect(json["data"]).to include("kind" => "growth", "annual_rate_bps" => 1_200, "monthly_rate_e8" => 948_879)
    expect(json["data"]["months"].first).to eq("month" => 1, "contributed_cents" => 110_000, "value_cents" => 110_949, "earnings_cents" => 949)
    expect(json["data"]["summary"]).to eq("contributed_cents" => 220_000, "value_cents" => 238_465, "earnings_cents" => 18_465)
  end

  it "validates the inputs of each kind" do
    simulate(kind: "growth", months: 601)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["error"]["details"].keys).to contain_exactly("months", "monthly_cents", "annual_rate_bps")

    simulate(kind: "income", months: 12, monthly_cents: 100)
    expect(json["error"]["details"]["monthly_yield_bps"].pluck("code")).to eq(%w[blank])

    simulate(kind: "saving", months: 12, monthly_cents: 100)
    expect(json["error"]["details"]["kind"].pluck("code")).to eq(%w[inclusion])
  end

  it "needs a listed asset with a price and income to project" do
    simulate(kind: "income", ticker: "XXXX11", months: 12, monthly_cents: 100)
    expect(json["error"]["details"]["ticker"].pluck("code")).to eq(%w[unknown_asset])

    simulate(kind: "income", ticker: fund.ticker, months: 12, monthly_cents: 100)
    expect(json["error"]["details"]["ticker"].pluck("code")).to eq(%w[no_income_data])

    stock = create(:asset, ticker: "VALE3")
    create(:asset_indicator, asset: stock, price_cents: 6_000)
    simulate(kind: "income", ticker: "VALE3", months: 12, monthly_cents: 100)
    expect(json["error"]["details"]["ticker"].pluck("code")).to eq(%w[no_income_data])
  end
end
