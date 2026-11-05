require "rails_helper"

RSpec.describe "Balances", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:others) { create(:balance) }
  let(:valid_params) { { amount_cents: -12_345, as_of: Date.current.iso8601 } }
  let(:invalid_params) { { amount_cents: "" } }

  it "requires authentication" do
    get "/api/v1/balances"
    expect(response).to have_http_status(:unauthorized)
  end

  describe "POST /api/v1/balances" do
    it "creates a balance owned by the current user, ignoring any user_id sent" do
      post "/api/v1/balances", params: valid_params.merge(user_id: others.user_id), headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("amount_cents" => -12_345, "as_of" => Date.current.iso8601)
      expect(json["data"]).not_to have_key("user_id")
      expect(Balance.find(json.dig("data", "id")).user).to eq(user)
    end

    it "returns per-field errors" do
      post "/api/v1/balances", params: invalid_params, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "amount_cents", 0, "code")).to eq("blank")
    end

    it "rejects a future date and a second balance on the same date" do
      post "/api/v1/balances", params: { amount_cents: 1, as_of: (Date.current + 1).iso8601 }, headers: headers, as: :json
      expect(json.dig("error", "details", "as_of", 0, "code")).to eq("in_future")

      create(:balance, user: user, as_of: Date.current)
      post "/api/v1/balances", params: valid_params, headers: headers, as: :json
      expect(json.dig("error", "details", "as_of", 0, "code")).to eq("taken")
    end
  end

  describe "GET /api/v1/balances" do
    it "lists only the user's balances, most recent date first, paginated" do
      older = create(:balance, user: user, as_of: 30.days.ago.to_date)
      newer = create(:balance, user: user, as_of: 1.day.ago.to_date, created_at: 1.year.ago)
      others

      get "/api/v1/balances", params: { limit: 1 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["data"].map { |record| record["id"] }).to eq([ newer.id ])
      expect(json["meta"]).to include("total" => 2, "next" => 2)

      get "/api/v1/balances", params: { page: 2, limit: 1 }, headers: headers
      expect(json["data"].map { |record| record["id"] }).to eq([ older.id ])
    end
  end

  describe "a single balance" do
    let(:balance) { create(:balance, user: user) }

    it "shows the owner's balance" do
      get "/api/v1/balances/#{balance.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "id")).to eq(balance.id)
    end

    it "updates with PATCH and PUT" do
      patch "/api/v1/balances/#{balance.id}", params: valid_params, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "amount_cents")).to eq(-12_345)

      put "/api/v1/balances/#{balance.id}", params: { amount_cents: 99 }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(balance.reload.amount_cents).to eq(99)
    end

    it "rejects an invalid update" do
      patch "/api/v1/balances/#{balance.id}", params: invalid_params, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "deletes the owner's balance" do
      delete "/api/v1/balances/#{balance.id}", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(Balance.exists?(balance.id)).to be(false)
    end
  end

  it "answers 404 for another user's balance, even to admins" do
    get "/api/v1/balances/#{others.id}", headers: headers
    expect(response).to have_http_status(:not_found)

    patch "/api/v1/balances/#{others.id}", params: valid_params, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/balances/#{others.id}", headers: headers
    expect(response).to have_http_status(:not_found)

    get "/api/v1/balances/#{others.id}", headers: auth_headers(create(:user, :admin))
    expect(response).to have_http_status(:not_found)
  end
end
