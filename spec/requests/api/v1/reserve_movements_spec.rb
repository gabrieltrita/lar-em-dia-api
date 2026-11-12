require "rails_helper"

RSpec.describe "Reserve movements", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:account) { create(:reserve_account, user: user) }
  let(:deposit) { { account_id: account.id, kind: "deposit", moved_on: "2026-10-01", amount_cents: 100_000 } }

  before do
    create(:category, :expense, key: "reserve_deposit")
    create(:category, key: "reserve_withdrawal")
  end

  def create_movement(params = deposit)
    post "/api/v1/reserve_movements", params: params, headers: headers, as: :json
    json["data"]
  end

  it "requires authentication" do
    get "/api/v1/reserve_movements"

    expect(response).to have_http_status(:unauthorized)
  end

  it "records a deposit that debits the balance" do
    data = create_movement(deposit.merge(debit_balance: true))

    expect(response).to have_http_status(:created)
    expect(data).to include("account_id" => account.id, "kind" => "deposit", "moved_on" => "2026-10-01", "amount_cents" => 100_000)
    expect(Entry.find(data["entry_id"])).to have_attributes(amount_cents: 100_000, status: "paid", kind: "expense")
  end

  it "answers validation errors with stable codes" do
    create_movement(deposit.merge(kind: "withdrawal"))
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "amount_cents", 0, "code")).to eq("insufficient_reserve")

    create_movement(deposit.merge(kind: "anchor", debit_balance: true))
    expect(json.dig("error", "details", "debit_balance", 0, "code")).to eq("anchor_not_allowed")

    create_movement(deposit.merge(account_id: create(:reserve_account).id))
    expect(json.dig("error", "details", "account", 0, "code")).to eq("required")
  end

  it "lists the user's movements filtered by account and dates" do
    first = create_movement
    create_movement(deposit.merge(moved_on: "2026-10-20"))
    other_account = create(:reserve_account, user: user)
    create_movement(deposit.merge(account_id: other_account.id))
    create(:reserve_movement)

    get "/api/v1/reserve_movements", params: { account_id: account.id, from: "2026-09-01", to: "2026-10-10" }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(json["data"].pluck("id")).to eq([ first["id"] ])
    expect(json["meta"]).to include("total" => 1)

    get "/api/v1/reserve_movements", headers: headers
    expect(json["meta"]).to include("total" => 3)
  end

  it "answers 400 for a bad date filter" do
    get "/api/v1/reserve_movements", params: { to: "october" }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(json.dig("error", "code")).to eq("invalid_date")
  end

  it "shows, updates and replaces a movement" do
    id = create_movement["id"]

    get "/api/v1/reserve_movements/#{id}", headers: headers
    expect(json.dig("data", "amount_cents")).to eq(100_000)

    patch "/api/v1/reserve_movements/#{id}", params: { amount_cents: 80_000 }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "amount_cents")).to eq(80_000)

    put "/api/v1/reserve_movements/#{id}", params: { moved_on: "2026-10-02" }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)

    patch "/api/v1/reserve_movements/#{id}", params: { account_id: create(:reserve_account, user: user).id }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "account_id", 0, "code")).to eq("immutable")
  end

  it "hides other users' movements" do
    other = create(:reserve_movement)

    get "/api/v1/reserve_movements/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)

    patch "/api/v1/reserve_movements/#{other.id}", params: { amount_cents: 1 }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/reserve_movements/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "deletes a movement unless a later withdrawal needs it" do
    first = create_movement
    create_movement(deposit.merge(kind: "withdrawal", moved_on: "2026-10-05", amount_cents: 50_000))

    delete "/api/v1/reserve_movements/#{first['id']}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "code")).to eq("insufficient_reserve")

    second = create_movement(deposit.merge(moved_on: "2026-10-02"))
    delete "/api/v1/reserve_movements/#{second['id']}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json["data"]).to eq("deleted_id" => second["id"])
  end
end
