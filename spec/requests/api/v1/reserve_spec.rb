require "rails_helper"

RSpec.describe "Reserve", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  around { |example| travel_to(Date.new(2026, 11, 12)) { example.run } }

  before do
    load_interest_rates
    account = create(:reserve_account, user: user)
    create(:reserve_movement, user: user, account: account, moved_on: Date.new(2026, 10, 1), amount_cents: 1_000_000)
  end

  it "requires authentication" do
    get "/api/v1/reserve"

    expect(response).to have_http_status(:unauthorized)
  end

  it "shows the reserve today" do
    get "/api/v1/reserve", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "totals")).to eq(
      "gross_cents" => 1_014_319, "net_cents" => 1_011_097, "invested_cents" => 1_000_000, "yield_cents" => 14_319, "tax_cents" => 3_222
    )
    expect(json.dig("data", "accounts", 0)).to include("kind" => "selic_treasury", "net_cents" => 1_011_097)
    expect(json["data"]).to include("suggestion" => nil, "alerts" => [], "rates_as_of" => "2026-11-11")
  end

  it "changes the goal and goes back to the suggestion" do
    patch "/api/v1/reserve", params: { goal_months: 12, goal_cents: 2_000_000 }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "goal")).to eq("months" => 12, "cents" => 2_000_000, "target_cents" => 2_000_000)
    expect(json.dig("data", "alerts")).to eq([ "below_suggestion" ])

    put "/api/v1/reserve", params: { goal_cents: nil }, headers: headers, as: :json
    expect(json.dig("data", "goal")).to eq("months" => 12, "cents" => nil, "target_cents" => nil)
  end

  it "answers validation errors by the request fields" do
    patch "/api/v1/reserve", params: { goal_months: 25, goal_cents: 0 }, headers: headers, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "goal_months", 0, "code")).to eq("less_than_or_equal_to")
    expect(json.dig("error", "details", "goal_cents", 0, "code")).to eq("greater_than")
  end

  it "projects the reserve month by month with its assumptions" do
    get "/api/v1/reserve/projection", params: { months: 3 }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "months").pluck("month")).to eq(%w[2026-11 2026-12 2027-01])
    expect(json.dig("data", "assumptions")).to include("selic_target_e8" => 13_750_000, "cdi_estimate_e8" => 13_650_000, "holidays_ignored" => true)

    get "/api/v1/reserve/projection", headers: headers
    expect(json.dig("data", "months").size).to eq(12)
  end

  it "answers 400 for an invalid number of months" do
    get "/api/v1/reserve/projection", params: { months: 61 }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(json.dig("error", "code")).to eq("invalid_months")
  end

  it "adds the net reserve to each month of the balance projection" do
    get "/api/v1/projection", params: { from: "2026-10", months: 2 }, headers: headers

    expect(json.dig("data", "months").pluck("reserve_cents")).to eq([ 1_008_308, 1_015_932 ])
  end
end
