require "rails_helper"

RSpec.describe "Projection simulation", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:expense) { create(:category, :expense, default_nature: :variable) }
  let(:income) { create(:category, :income) }

  def simulate(entries, **period)
    travel_to Time.zone.local(2026, 11, 10, 12) do
      post "/api/v1/projection/simulation", params: { entries: entries, **period }, headers: headers, as: :json
    end
  end

  def closings(key)
    json.dig("data", key, "months").pluck("closing_cents")
  end

  before { create(:balance, user: user, amount_cents: 100_000, as_of: "2026-11-01") }

  it "requires authentication" do
    post "/api/v1/projection/simulation", params: { entries: [] }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "adds a single hypothetical entry to the simulated projection only" do
    expect do
      simulate([ { category_id: expense.id, description: "New TV", amount_cents: 150_000, due_on: "2026-12-05" } ], months: 3)
    end.not_to change(Entry, :count)

    expect(response).to have_http_status(:ok)
    expect(closings("baseline")).to eq([ 100_000, 100_000, 100_000 ])
    expect(closings("simulated")).to eq([ 100_000, -50_000, -50_000 ])
    expect(json.dig("data", "simulated", "months", 1)).to include("variable_expense_cents" => 150_000, "negative" => true)
    expect(json.dig("data", "simulated", "alerts")).to eq("first_negative_month" => "2026-12", "negative_months_count" => 2)
    expect(json.dig("data", "baseline", "alerts", "negative_months_count")).to eq(0)
    expect(json.dig("data", "simulated", "anchor")).to eq("amount_cents" => 100_000, "as_of" => "2026-11-01")
  end

  it "projects through the last simulated entry with months all" do
    simulate([ { category_id: expense.id, description: "Car", due_on: "2026-12-05", kind: "installments", total_cents: 360_000, entries_count: 36 } ], months: "all")

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "simulated", "months").size).to eq(37)
    expect(json.dig("data", "simulated", "last_entry_month")).to eq("2029-11")
    expect(json.dig("data", "simulated", "months", 1, "expense_by_category")).to eq([ { "category_key" => expense.key, "amount_cents" => 10_000 } ])
    expect(json.dig("data", "baseline", "last_entry_month")).to be_nil
  end

  it "simulates installments and recurring income together" do
    simulate(
      [
        { category_id: expense.id, description: "Fridge", due_on: "2026-11-20", kind: "installments", total_cents: 30_001, entries_count: 3 },
        { category_id: income.id, description: "Freelance", amount_cents: 5_000, due_on: "2026-11-25", entries_count: 2, direction: "forward" }
      ],
      from: "2026-11", months: 4
    )

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "simulated", "months").pluck("expense_cents")).to eq([ 10_001, 10_000, 10_000, 0 ])
    expect(json.dig("data", "simulated", "months").pluck("income_cents")).to eq([ 5_000, 5_000, 0, 0 ])
    expect(closings("simulated")).to eq([ 94_999, 89_999, 79_999, 79_999 ])
    expect(EntrySeries.count).to eq(0)
  end

  it "counts hypothetical entries before the first month in the opening balance" do
    simulate(
      [
        { category_id: income.id, description: "Bonus", amount_cents: 20_000, due_on: "2026-11-15" },
        { category_id: expense.id, description: "Gift", amount_cents: 5_000, due_on: "2026-12-15" }
      ],
      from: "2027-01", months: 1
    )

    expect(json.dig("data", "baseline", "months", 0, "opening_cents")).to eq(100_000)
    expect(json.dig("data", "simulated", "months", 0, "opening_cents")).to eq(115_000)
  end

  it "returns whole cents when real entries fall between the start of the month and the balance" do
    travel_to Time.zone.local(2026, 11, 10, 12) do
      create(:balance, user: user, amount_cents: 100_000, as_of: "2026-11-08")
      create(:entry, user: user, category: income, amount_cents: 40_000, due_on: "2026-11-03")
    end

    simulate([ { category_id: expense.id, description: "Chair", amount_cents: 1_000, due_on: "2026-11-20" } ], months: 1)

    expect(response).to have_http_status(:ok)
    %w[baseline simulated].each do |key|
      expect(json.dig("data", key, "months", 0).values_at("opening_cents", "closing_cents", "savings_cents")).to all(be_an(Integer))
    end
    expect(json.dig("data", "simulated", "months", 0, "opening_cents")).to eq(60_000)
  end

  it "ignores hypothetical entries after the period" do
    simulate([ { category_id: expense.id, description: "Later", amount_cents: 1_000, due_on: "2027-06-01" } ], months: 2)

    expect(closings("simulated")).to eq(closings("baseline"))
  end

  it "keys validation errors by the position of the entry" do
    simulate(
      [
        { category_id: expense.id, description: "Ok", amount_cents: 1_000, due_on: "2026-12-01" },
        { category_id: expense.id, description: "", amount_cents: 0, due_on: "2026-12-01" },
        { category_id: income.id, description: "Parcel", due_on: "2026-12-01", kind: "installments", total_cents: 1, entries_count: 2 }
      ]
    )

    expect(response).to have_http_status(:unprocessable_content)
    details = json.dig("error", "details")
    expect(details.dig("entries.1.description", 0, "code")).to eq("blank")
    expect(details.dig("entries.1.amount_cents", 0, "code")).to eq("greater_than")
    expect(details.dig("entries.2.kind", 0, "code")).to eq("only_for_expenses")
    expect(details.keys).not_to include(a_string_starting_with("entries.0"))
  end

  it "requires between one and ten entries" do
    simulate([])
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "entries", 0, "code")).to eq("blank")

    simulate(Array.new(11) { { category_id: expense.id, description: "x", amount_cents: 1, due_on: "2026-12-01" } })
    expect(json.dig("error", "details", "entries", 0, "code")).to eq("too_long")
  end

  it "rejects a malformed period" do
    simulate([], from: "2026-13")
    expect(response).to have_http_status(:bad_request)
    expect(json.dig("error", "code")).to eq("invalid_month")

    simulate([], months: 30)
    expect(json.dig("error", "code")).to eq("invalid_months")
  end
end
