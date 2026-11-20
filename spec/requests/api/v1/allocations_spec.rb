require "rails_helper"

RSpec.describe "Allocations", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  around { |example| travel_to(Date.new(2026, 11, 20)) { example.run } }

  before do
    create(:category, :expense, key: "surplus_allocation")
    create(:category, :expense, key: "reserve_deposit")
    create(:balance, user: user, as_of: Date.new(2026, 10, 31), amount_cents: 9_400)
  end

  it "requires authentication" do
    get "/api/v1/allocation_plan"

    expect(response).to have_http_status(:unauthorized)
  end

  it "plans the current month, uses a destination, takes it out of the closing balance and undoes it" do
    charity = create(:allocation_target, user: user, name: "Caridade", percent_bps: 800)
    create(:allocation_target, :remainder, user: user)

    get "/api/v1/allocation_plan", headers: headers
    expect(json["data"]).to include("month" => "2026-11", "closing_cents" => 9_400, "planned_cents" => 9_400)
    expect(json.dig("data", "items").pluck("name", "amount_cents", "used")).to eq([ [ "Caridade", 752, false ], [ "Reserva", 8_648, false ] ])

    post "/api/v1/allocations", params: { target_id: charity.id, month: "2026-11" }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("target_id" => charity.id, "month" => "2026-11", "amount_cents" => 752, "used_on" => "2026-11-20")
    id = json.dig("data", "id")

    get "/api/v1/projection", params: { months: 1 }, headers: headers
    expect(json.dig("data", "months", 0, "closing_cents")).to eq(8_648)

    get "/api/v1/allocation_plan", params: { month: "2026-11" }, headers: headers
    expect(json["data"]).to include("closing_cents" => 8_648, "base_cents" => 9_400, "used_cents" => 752)
    expect(json.dig("data", "items", 0)).to include("used" => true, "allocation_id" => id, "used_on" => "2026-11-20")

    delete "/api/v1/allocations/#{id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json["data"]).to eq("deleted_id" => id)
    expect(Entry.count).to eq(0)
  end

  it "uses a chosen amount in a past month" do
    target = create(:allocation_target, :fixed, user: user)

    post "/api/v1/allocations", params: { target_id: target.id, month: "2026-09", amount_cents: 300 }, headers: headers, as: :json

    expect(json["data"]).to include("month" => "2026-09", "amount_cents" => 300, "used_on" => "2026-09-30")
  end

  it "refuses bad months, future months and another user's destination" do
    target = create(:allocation_target, user: user)

    get "/api/v1/allocation_plan", params: { month: "2026-13" }, headers: headers
    expect(response).to have_http_status(:bad_request)
    expect(json.dig("error", "code")).to eq("invalid_month")

    post "/api/v1/allocations", params: { target_id: target.id, month: "11/2026" }, headers: headers, as: :json
    expect(response).to have_http_status(:bad_request)
    expect(json.dig("error", "code")).to eq("invalid_month")

    post "/api/v1/allocations", params: { target_id: target.id, month: "2026-12" }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "month", 0, "code")).to eq("in_future")

    post "/api/v1/allocations", params: { target_id: create(:allocation_target).id, month: "2026-11" }, headers: headers, as: :json
    expect(json.dig("error", "details", "target", 0, "code")).to eq("required")
  end

  it "refuses to undo a reserve deposit that a later withdrawal needs and hides other users' allocations" do
    account = create(:reserve_account, user: user)
    target = create(:allocation_target, :fixed, user: user, reserve_account: account)
    post "/api/v1/allocations", params: { target_id: target.id, month: "2026-11" }, headers: headers, as: :json
    id = json.dig("data", "id")
    create(:reserve_movement, user: user, account: account, kind: :withdrawal, amount_cents: 1_000, moved_on: Date.new(2026, 11, 20))

    delete "/api/v1/allocations/#{id}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "code")).to eq("insufficient_reserve")

    delete "/api/v1/allocations/#{create(:allocation).id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
