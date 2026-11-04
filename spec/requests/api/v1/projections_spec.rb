require "rails_helper"

RSpec.describe "Projection", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it "requires authentication" do
    get "/api/v1/projection"
    expect(response).to have_http_status(:unauthorized)
  end

  it "projects twelve months from the current month by default" do
    travel_to Time.zone.local(2026, 11, 15, 12) do
      create(:balance, user: user, amount_cents: 100_000, as_of: "2026-11-01")
      create(:entry, user: user, category: create(:category, :expense, default_nature: :fixed), amount_cents: 30_000, due_on: "2026-11-20")

      get "/api/v1/projection", headers: headers
    end

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "anchor")).to eq("amount_cents" => 100_000, "as_of" => "2026-11-01")
    months = json.dig("data", "months")
    expect(months.size).to eq(12)
    expect(months.first).to eq(
      "month" => "2026-11", "opening_cents" => 100_000, "income_cents" => 0, "expense_cents" => 30_000,
      "fixed_expense_cents" => 30_000, "variable_expense_cents" => 0, "closing_cents" => 70_000,
      "savings_cents" => -30_000, "negative" => false
    )
    expect(json.dig("data", "alerts")).to eq("first_negative_month" => nil, "negative_months_count" => 0)
    expect(months.last).to include("month" => "2027-10", "closing_cents" => 70_000, "savings_cents" => -30_000)
  end

  it "accepts a starting month and a number of months, without an anchor" do
    get "/api/v1/projection", params: { from: "2027-01", months: "24" }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "anchor")).to be_nil
    expect(json.dig("data", "months").pluck("month").values_at(0, -1)).to eq(%w[2027-01 2028-12])
  end

  it "only uses the current user's data" do
    create(:balance, amount_cents: 500_000, as_of: "2026-01-01")
    create(:entry, due_on: "2026-01-05")

    get "/api/v1/projection", params: { from: "2026-01", months: 1 }, headers: headers

    expect(json.dig("data", "months", 0)).to include("opening_cents" => 0, "income_cents" => 0, "closing_cents" => 0)
  end

  it "rejects a malformed month" do
    %w[2026-13 2026-1 11/2026 2026-11-01].each do |from|
      get "/api/v1/projection", params: { from: from }, headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "code")).to eq("invalid_month")
    end
  end

  it "rejects a number of months outside 1 to 24" do
    %w[0 25 twelve 1.5].each do |months|
      get "/api/v1/projection", params: { months: months }, headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "code")).to eq("invalid_months")
    end
  end
end
