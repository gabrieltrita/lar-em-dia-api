require "rails_helper"

RSpec.describe "Investment transactions", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let!(:petr) { create(:asset, ticker: "PETR4") }
  let(:buy) { { ticker: "PETR4", kind: "buy", traded_on: "2026-10-01", quantity: 100, price_cents: 3_000, fees_cents: 50 } }

  before do
    create(:category, :expense, key: "investment_contribution")
    create(:category, key: "investment_redemption")
  end

  def create_transaction(params = buy)
    post "/api/v1/investment_transactions", params: params, headers: headers, as: :json
    json["data"]
  end

  it "requires authentication" do
    get "/api/v1/investment_transactions"

    expect(response).to have_http_status(:unauthorized)
  end

  it "records a buy that debits the balance" do
    data = create_transaction(buy.merge(debit_balance: true))

    expect(response).to have_http_status(:created)
    expect(data).to include("ticker" => "PETR4", "kind" => "buy", "quantity" => 100, "price_cents" => 3_000, "fees_cents" => 50)
    expect(Entry.find(data["entry_id"])).to have_attributes(amount_cents: 300_050, status: "paid")
  end

  it "answers validation errors with stable codes" do
    create_transaction(buy.merge(ticker: "XXXX3"))
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "ticker", 0, "code")).to eq("unknown_asset")

    create_transaction(buy.merge(kind: "split", price_cents: 10))
    expect(json.dig("error", "details", "price_cents", 0, "code")).to eq("only_for_trades")

    create_transaction(buy.merge(kind: "sell", quantity: 1))
    expect(json.dig("error", "details", "quantity", 0, "code")).to eq("insufficient_quantity")
  end

  it "lists the user's transactions filtered by ticker and dates" do
    first = create_transaction
    create_transaction(buy.merge(traded_on: "2026-10-20"))
    create(:investment_transaction)

    get "/api/v1/investment_transactions", params: { ticker: "petr4", from: "2026-09-01", to: "2026-10-10" }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"].pluck("id")).to eq([ first["id"] ])
    expect(json["meta"]).to include("total" => 1)

    get "/api/v1/investment_transactions", params: { to: "2026-10-10" }, headers: headers
    expect(json["data"].pluck("id")).to eq([ first["id"] ])

    get "/api/v1/investment_transactions", headers: headers
    expect(json["meta"]).to include("total" => 2)
  end

  it "answers 400 for a bad date filter" do
    get "/api/v1/investment_transactions", params: { from: "october" }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(json.dig("error", "code")).to eq("invalid_date")
  end

  it "shows, updates and replaces a transaction" do
    id = create_transaction["id"]

    get "/api/v1/investment_transactions/#{id}", headers: headers
    expect(json.dig("data", "quantity")).to eq(100)

    patch "/api/v1/investment_transactions/#{id}", params: { quantity: 80 }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "quantity")).to eq(80)

    put "/api/v1/investment_transactions/#{id}", params: { fees_cents: 0 }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)

    patch "/api/v1/investment_transactions/#{id}", params: { ticker: "VALE3" }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "ticker", 0, "code")).to eq("immutable")
  end

  it "hides other users' transactions" do
    other = create(:investment_transaction)

    get "/api/v1/investment_transactions/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)

    patch "/api/v1/investment_transactions/#{other.id}", params: { quantity: 1 }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/investment_transactions/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end

  it "deletes a transaction unless a later sale needs it" do
    first = create_transaction
    create_transaction(buy.merge(kind: "sell", traded_on: "2026-10-05"))

    delete "/api/v1/investment_transactions/#{first['id']}", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "code")).to eq("insufficient_quantity")

    second = create_transaction(buy.merge(traded_on: "2026-10-02"))
    delete "/api/v1/investment_transactions/#{second['id']}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(json["data"]).to eq("deleted_id" => second["id"])
  end
end
