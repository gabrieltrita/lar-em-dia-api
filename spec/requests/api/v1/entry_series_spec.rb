require "rails_helper"

RSpec.describe "Entry series", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:salary) { create(:category, key: "salary") }
  let(:valid_params) do
    { category_id: salary.id, description: "Salary", amount_cents: 650_000, due_on: "2026-11-05", entries_count: 3, direction: "forward" }
  end

  around { |example| travel_to(Time.zone.local(2026, 11, 20, 12)) { example.run } }

  it "requires authentication" do
    post "/api/v1/entry_series", params: valid_params, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  describe "POST /api/v1/entry_series" do
    it "creates the series and its entries for the current user" do
      post "/api/v1/entry_series", params: valid_params.merge(status: "paid", paid_on: "2026-11-05"), headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("kind" => "recurring", "interval_months" => 1, "entries_count" => 3)
      entries = json.dig("data", "entries")
      expect(entries.map { |entry| entry.values_at("due_on", "status", "series_position") }).to eq(
        [ [ "2026-11-05", "paid", 1 ], [ "2026-12-05", "pending", 2 ], [ "2027-01-05", "pending", 3 ] ]
      )
      expect(entries.pluck("series_id").uniq).to eq([ json.dig("data", "id") ])
      expect(user.entries.count).to eq(3)
    end

    it "repeats in fixed months of the following years" do
      post "/api/v1/entry_series", params: valid_params.merge(description: "FGTS", due_on: "2027-05-10", interval_months: 12), headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("interval_months" => 12)
      expect(json.dig("data", "entries").pluck("due_on")).to eq(%w[2027-05-10 2028-05-10 2029-05-10])
    end

    it "shows the series on each entry" do
      post "/api/v1/entry_series", params: valid_params, headers: headers, as: :json
      entry = Entry.find(json.dig("data", "entries", 1, "id"))

      get "/api/v1/entries/#{entry.id}", headers: headers

      expect(json["data"]).to include("series_id" => entry.series_id, "series_position" => 2)
    end

    it "returns per-field errors and creates nothing" do
      post "/api/v1/entry_series", params: valid_params.merge(entries_count: 1, direction: "up", interval_months: 4, description: ""), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      details = json.dig("error", "details")
      expect(details.dig("entries_count", 0, "code")).to eq("greater_than_or_equal_to")
      expect(details.dig("direction", 0, "code")).to eq("inclusion")
      expect(details.dig("interval_months", 0, "code")).to eq("inclusion")
      expect(details.dig("description", 0, "code")).to eq("blank")
      expect(Entry.count).to eq(0)
    end

    context "with installments" do
      let(:furniture) { create(:category, :expense, key: "furniture") }
      let(:installments) do
        { kind: "installments", category_id: furniture.id, description: "Sofa", total_cents: 120_000, due_on: "2026-11-10", entries_count: 10 }
      end

      it "splits the total into monthly installments" do
        post "/api/v1/entry_series", params: installments, headers: headers, as: :json

        expect(response).to have_http_status(:created)
        expect(json["data"]).to include("kind" => "installments", "entries_count" => 10, "total_cents" => 120_000)
        entries = json.dig("data", "entries")
        expect(entries.pluck("amount_cents").uniq).to eq([ 12_000 ])
        expect(entries.last).to include("due_on" => "2027-08-10", "series_kind" => "installments", "series_count" => 10)
      end

      it "lists each installment with its series" do
        post "/api/v1/entry_series", params: installments, headers: headers, as: :json

        get "/api/v1/entries", params: { from: "2026-12-01", to: "2026-12-31" }, headers: headers

        expect(json["data"].sole).to include("series_position" => 2, "series_kind" => "installments", "series_count" => 10)
      end

      it "refuses income installments and a missing total" do
        post "/api/v1/entry_series", params: installments.merge(category_id: salary.id, total_cents: nil), headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        details = json.dig("error", "details")
        expect(details.dig("kind", 0, "code")).to eq("only_for_expenses")
        expect(details.dig("total_cents", 0, "code")).to eq("not_a_number")
        expect(details).not_to have_key("amount_cents")
      end

      it "refuses a total on a recurring series" do
        post "/api/v1/entry_series", params: valid_params.merge(total_cents: 100), headers: headers, as: :json

        expect(json.dig("error", "details", "total_cents", 0, "code")).to eq("present")
      end
    end
  end

  describe "projection in the answer" do
    it "answers the projection with the whole series" do
      post "/api/v1/entry_series?projection_from=2026-11&projection_months=all", params: valid_params, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json.dig("meta", "projection", "months").map { |month| month["income_cents"] }).to eq([ 650_000 ] * 3)
    end

    it "rejects an invalid period before creating anything" do
      expect {
        post "/api/v1/entry_series?projection_from=2026-1", params: valid_params, headers: headers, as: :json
      }.not_to change(Entry, :count)
      expect(response).to have_http_status(:bad_request)
      expect(json.dig("error", "code")).to eq("invalid_month")
    end
  end

  it "answers without meta when no projection is asked" do
    post "/api/v1/entry_series", params: valid_params, headers: headers, as: :json
    expect(json).not_to have_key("meta")
  end
end
