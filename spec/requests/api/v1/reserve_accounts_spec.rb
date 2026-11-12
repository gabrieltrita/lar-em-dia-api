require "rails_helper"

RSpec.describe "Reserve accounts", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:cdb) { { name: "CDB liquidez diária", kind: "cdb", cdi_percent_bps: 10_500 } }

  it "requires authentication" do
    get "/api/v1/reserve_accounts"

    expect(response).to have_http_status(:unauthorized)
  end

  it "creates, lists, shows, updates and replaces accounts" do
    post "/api/v1/reserve_accounts", params: cdb, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    id = json.dig("data", "id")
    expect(json["data"]).to include("name" => "CDB liquidez diária", "kind" => "cdb", "cdi_percent_bps" => 10_500, "tax_exempt" => false)
    create(:reserve_account)

    get "/api/v1/reserve_accounts", headers: headers
    expect(json["data"].pluck("id")).to eq([ id ])

    get "/api/v1/reserve_accounts/#{id}", headers: headers
    expect(json.dig("data", "name")).to eq("CDB liquidez diária")

    patch "/api/v1/reserve_accounts/#{id}", params: { kind: "selic_treasury", cdi_percent_bps: nil }, headers: headers, as: :json
    expect(json.dig("data", "kind")).to eq("selic_treasury")

    put "/api/v1/reserve_accounts/#{id}", params: { name: "Tesouro" }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
  end

  it "answers validation errors with stable codes" do
    post "/api/v1/reserve_accounts", params: cdb.except(:cdi_percent_bps), headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "cdi_percent_bps", 0, "code")).to eq("rate_required")

    post "/api/v1/reserve_accounts", params: cdb.merge(kind: "savings"), headers: headers, as: :json
    expect(json.dig("error", "details", "cdi_percent_bps", 0, "code")).to eq("rate_not_allowed")

    account = create(:reserve_account, user: user)
    patch "/api/v1/reserve_accounts/#{account.id}", params: { kind: "fixed_rate" }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "annual_rate_bps", 0, "code")).to eq("rate_required")
  end

  it "deletes an account with its movements and their entries" do
    account = create(:reserve_account, user: user)
    entry = create(:entry, user: user)
    create(:reserve_movement, user: user, account: account, entry: entry)

    delete "/api/v1/reserve_accounts/#{account.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"]).to eq("deleted_id" => account.id)
    expect(Entry.exists?(entry.id)).to be(false)
  end

  it "hides other users' accounts" do
    other = create(:reserve_account)

    get "/api/v1/reserve_accounts/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)

    patch "/api/v1/reserve_accounts/#{other.id}", params: { name: "x" }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/reserve_accounts/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
