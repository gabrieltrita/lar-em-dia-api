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

    it "gives an expense its category's default nature unless one is sent" do
      groceries = create(:category, :expense, key: "groceries")
      post "/api/v1/entries", params: valid_params.merge(category_id: groceries.id), headers: headers, as: :json
      expect(json["data"]).to include("kind" => "expense", "nature" => "variable")

      post "/api/v1/entries", params: valid_params.merge(category_id: groceries.id, nature: "fixed"), headers: headers, as: :json
      expect(json["data"]).to include("nature" => "fixed")
    end

    it "rejects a nature on income" do
      post "/api/v1/entries", params: valid_params.merge(nature: "fixed"), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "nature", 0, "code")).to eq("only_for_expenses")
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

      get "/api/v1/entries", params: { nature: "variable" }, headers: headers
      expect(json["data"].map { |entry| entry["id"] }).to eq([ november_rent.id ])

      get "/api/v1/entries", params: { nature: "fixed" }, headers: headers
      expect(json["data"]).to be_empty

      get "/api/v1/entries", params: { kind: "unknown", nature: "unknown", limit: 2 }, headers: headers
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

  describe "series scopes" do
    let(:housing) { create(:category, key: "housing", kind: :expense, default_nature: :fixed) }
    let(:recurring) { create_series(entries_count: 4, amount_cents: 200_000, due_on: "2026-01-31") }
    let(:installments) { create_series(kind: "installments", entries_count: 3, total_cents: 100_00, due_on: "2026-11-10") }

    def create_series(**options)
      attributes = { category_id: housing.id, description: "Rent", amount_cents: options.delete(:amount_cents), due_on: options.delete(:due_on) }
      creator = EntrySeriesCreator.new(user: user, attributes: attributes, count: options.delete(:entries_count), direction: "forward", **options)
      creator.call
      creator.series
    end

    def entry_at(series, position)
      series.entries.find_by!(series_position: position)
    end

    it "edits this and the following entries, moving their day of the month" do
      second = entry_at(recurring, 2)
      patch "/api/v1/entries/#{second.id}", params: { scope: "following", description: "New rent", amount_cents: 210_000, due_on: "2026-02-15", status: "pending" },
                                            headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "due_on")).to eq("2026-02-15")
      entries = recurring.entries.reload
      expect(entries.map(&:description)).to eq([ "Rent", "New rent", "New rent", "New rent" ])
      expect(entries.map(&:amount_cents)).to eq([ 200_000, 210_000, 210_000, 210_000 ])
      expect(entries.map(&:due_on).map(&:iso8601)).to eq(%w[2026-01-31 2026-02-15 2026-03-15 2026-04-15])
    end

    it "edits every entry, keeping the month end adjustment" do
      patch "/api/v1/entries/#{entry_at(recurring, 3).id}", params: { scope: "all", due_on: "2026-03-30" }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(recurring.entries.reload.map(&:due_on).map(&:iso8601)).to eq(%w[2026-01-30 2026-02-28 2026-03-30 2026-04-30])
    end

    it "rejects status and paid_on changes outside a single entry" do
      patch "/api/v1/entries/#{entry_at(recurring, 1).id}", params: { scope: "all", status: "paid", paid_on: "2026-01-31" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("only_for_single_entry")
      expect(recurring.entries.reload).to all(be_pending)
    end

    it "locks the amount of installments outside a single entry" do
      first = entry_at(installments, 1)
      patch "/api/v1/entries/#{first.id}", params: { scope: "following", amount_cents: 5_000 }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("installment_amount_locked")

      patch "/api/v1/entries/#{first.id}", params: { scope: "all", amount_cents: first.amount_cents, description: "Sofa" }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(installments.entries.reload.map(&:description)).to all(eq("Sofa"))
    end

    it "rolls every entry back when one is invalid" do
      patch "/api/v1/entries/#{entry_at(recurring, 1).id}", params: { scope: "all", description: "" }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "description", 0, "code")).to eq("blank")

      patch "/api/v1/entries/#{entry_at(recurring, 1).id}", params: { scope: "all", due_on: "not a date" }, headers: headers, as: :json
      expect(json.dig("error", "details", "due_on", 0, "code")).to eq("blank")
      expect(recurring.entries.reload.map(&:description)).to all(eq("Rent"))
    end

    it "changes only the entry with scope one or without a series" do
      patch "/api/v1/entries/#{entry_at(recurring, 1).id}", params: { scope: "one", status: "paid", paid_on: "2026-01-31" }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(recurring.entries.reload.map(&:status)).to eq(%w[paid pending pending pending])

      single = create(:entry, user: user, category: salary)
      patch "/api/v1/entries/#{single.id}", params: { scope: "all", status: "paid", paid_on: single.due_on.iso8601 }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(single.reload).to be_paid
    end

    it "deletes this and the following entries and recounts the series" do
      delete "/api/v1/entries/#{entry_at(installments, 2).id}", params: { scope: "following" }, headers: headers

      expect(response).to have_http_status(:no_content)
      expect(installments.reload.entries_count).to eq(1)
      expect(installments.total_cents).to eq(installments.entries.sum(:amount_cents))

      delete "/api/v1/entries/#{entry_at(recurring, 3).id}", params: { scope: "following" }, headers: headers
      expect(recurring.reload).to have_attributes(entries_count: 2, total_cents: nil)
    end

    it "deletes the whole series" do
      delete "/api/v1/entries/#{entry_at(recurring, 2).id}", params: { scope: "all" }, headers: headers

      expect(response).to have_http_status(:no_content)
      expect(EntrySeries.exists?(recurring.id)).to be(false)
      expect(Entry.where(series_id: recurring.id)).to be_empty
    end

    it "deletes one entry and drops the series once it is empty" do
      delete "/api/v1/entries/#{entry_at(installments, 1).id}", headers: headers
      expect(installments.reload.entries_count).to eq(3)

      delete "/api/v1/entries/#{entry_at(installments, 2).id}", params: { scope: "following" }, headers: headers
      expect(response).to have_http_status(:no_content)
      expect(EntrySeries.exists?(installments.id)).to be(false)
    end
  end
end
