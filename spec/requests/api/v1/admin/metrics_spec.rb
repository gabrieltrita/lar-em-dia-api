require "rails_helper"

RSpec.describe "Admin::Metrics", type: :request do
  let(:admin) { create(:user, :admin, created_at: 200.days.ago, last_sign_in_at: 1.day.ago) }

  around { |example| travel_to(Time.zone.local(2026, 11, 18, 12)) { example.run } }

  def series_for(user, count)
    create_list(:entry_series, count, user: user)
  end

  it "counts users and engagement without exposing any content" do
    carla = create(:user, last_sign_in_at: 2.days.ago)
    create(:balance, user: carla)
    create(:entry, user: carla, description: "Private rent", amount_cents: 123_456)
    series_for(carla, 5)
    bruno = create(:user, :unconfirmed, created_at: 50.days.ago)
    series_for(bruno, 4)
    create(:user, deactivated_at: 1.day.ago, created_at: 9.days.ago)
    create(:user, anonymized_at: 1.day.ago)
    create(:investment_transaction, user: carla)
    create(:investment_position, user: bruno, asset: create(:asset, :fii))
    create(:reserve_account, user: carla)
    create(:reserve_account, :cdb, user: carla)

    get "/api/v1/admin/metrics", headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "users")).to eq(
      "total" => 4, "confirmed" => 3, "active_30d" => 2, "new_30d" => 2, "deactivated" => 1, "with_two_factor" => 1
    )
    expect(json.dig("data", "engagement")).to eq(
      "with_balance" => 1, "with_entries" => 1, "with_5_series" => 1, "entries_created_30d" => 1,
      "with_portfolio" => 2, "investment_transactions_30d" => 1, "positions_by_goal" => { "income" => 1, "growth" => 1 },
      "with_reserve" => 1, "reserve_accounts_by_kind" => { "selic_treasury" => 1, "cdb" => 1, "savings" => 0, "idle" => 0, "fixed_rate" => 0 }
    )
    expect(response.body).not_to include("Private rent", "123456")
  end

  it "counts sign ups by week for the last twelve weeks" do
    create(:user, created_at: Time.zone.local(2026, 11, 17, 9))
    create(:user, created_at: Time.zone.local(2026, 11, 3, 9))
    create(:user, created_at: Time.zone.local(2026, 8, 1, 9))

    get "/api/v1/admin/metrics", headers: auth_headers(admin)

    weeks = json.dig("data", "signups_by_week")
    expect(weeks.size).to eq(12)
    expect(weeks.first).to eq("week" => "2026-08-31", "count" => 0)
    expect(weeks.last).to eq("week" => "2026-11-16", "count" => 1)
    expect(weeks.find { |week| week["week"] == "2026-11-02" }["count"]).to eq(1)
    expect(weeks.sum { |week| week["count"] }).to eq(2)
  end

  it "is admin only" do
    get "/api/v1/admin/metrics", headers: auth_headers(create(:user))

    expect(response).to have_http_status(:forbidden)
  end
end
