require "rails_helper"

RSpec.describe "Entries", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:others) { create(:entry) }
  let(:salary) { create(:category, key: "salary") }
  let(:valid_params) { { category_id: salary.id, description: "November salary", amount_cents: 650_000, due_on: "2026-11-05" } }
  let(:invalid_params) { { description: "" } }

  it "requires authentication" do
    get "/api/v1/entries"
    expect(response).to have_http_status(:unauthorized)
  end

  describe "POST /api/v1/entries" do
    it "creates a pending entry for the current user with the category's kind" do
      post "/api/v1/entries", params: valid_params.merge(user_id: others.user_id, kind: "expense"), headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include(
        "kind" => "income", "category_id" => salary.id, "description" => "November salary",
        "amount_cents" => 650_000, "due_on" => "2026-11-05", "status" => "pending", "paid_on" => nil
      )
      expect(json["data"]).not_to have_key("user_id")
      expect(Entry.find(json.dig("data", "id")).user).to eq(user)
    end

    it "creates a paid entry" do
      post "/api/v1/entries", params: valid_params.merge(status: "paid", paid_on: "2026-11-04"), headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("status" => "paid", "paid_on" => "2026-11-04")
    end

    it "returns per-field errors" do
      post "/api/v1/entries", params: valid_params.merge(amount_cents: 0, paid_on: "2026-11-04", category_id: nil), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      details = json.dig("error", "details")
      expect(details.dig("amount_cents", 0, "code")).to eq("greater_than")
      expect(details.dig("paid_on", 0, "code")).to eq("only_when_paid")
      expect(details.dig("category", 0, "code")).to eq("required")
    end
  end

  describe "GET /api/v1/entries" do
    let(:rent) { create(:category, :expense, key: "rent") }

    it "lists only the user's entries by due date, filtered by period and kind" do
      before_period = create(:entry, user: user, category: salary, due_on: "2026-10-31")
      bonus = create(:entry, user: user, category: salary, due_on: "2026-11-20")
      november_salary = create(:entry, user: user, category: salary, due_on: "2026-11-05")
      november_rent = create(:entry, user: user, category: rent, due_on: "2026-11-10")
      after_period = create(:entry, user: user, category: salary, due_on: "2026-12-01")
      others

      get "/api/v1/entries", params: { from: "2026-11-01", to: "2026-11-30" }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json["data"].map { |entry| entry["id"] }).to eq([ november_salary.id, november_rent.id, bonus.id ])

      get "/api/v1/entries", params: { from: "2026-11-01", to: "2026-11-30", kind: "income" }, headers: headers
      expect(json["data"].map { |entry| entry["id"] }).to eq([ november_salary.id, bonus.id ])

      get "/api/v1/entries", params: { kind: "unknown", limit: 2 }, headers: headers
      expect(json["data"].map { |entry| entry["id"] }).to eq([ before_period.id, november_salary.id ])
      expect(json["meta"]).to include("total" => 5, "next" => 2)

      get "/api/v1/entries", params: { from: "2026-12-01" }, headers: headers
      expect(json["data"].map { |entry| entry["id"] }).to eq([ after_period.id ])

      get "/api/v1/entries", params: { to: "2026-10-31" }, headers: headers
      expect(json["data"].map { |entry| entry["id"] }).to eq([ before_period.id ])
    end

    it "rejects a malformed date" do
      get "/api/v1/entries", params: { from: "11/01/2026" }, headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "code")).to eq("invalid_date")
    end
  end

  describe "a single entry" do
    let(:entry) { create(:entry, user: user, category: salary) }

    it "shows the owner's entry" do
      get "/api/v1/entries/#{entry.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "id")).to eq(entry.id)
    end

    it "updates with PATCH and PUT, including marking it as paid" do
      patch "/api/v1/entries/#{entry.id}", params: valid_params, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "description")).to eq("November salary")

      put "/api/v1/entries/#{entry.id}", params: { status: "paid", paid_on: "2026-11-05" }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(entry.reload).to be_paid
    end

    it "rejects an invalid update" do
      patch "/api/v1/entries/#{entry.id}", params: invalid_params, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "deletes the owner's entry" do
      delete "/api/v1/entries/#{entry.id}", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(Entry.exists?(entry.id)).to be(false)
    end
  end

  it "answers 404 for another user's entry, even to admins" do
    get "/api/v1/entries/#{others.id}", headers: headers
    expect(response).to have_http_status(:not_found)

    patch "/api/v1/entries/#{others.id}", params: valid_params, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/entries/#{others.id}", headers: headers
    expect(response).to have_http_status(:not_found)

    get "/api/v1/entries/#{others.id}", headers: auth_headers(create(:user, :admin))
    expect(response).to have_http_status(:not_found)
  end
end
