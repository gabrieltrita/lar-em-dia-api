require "rails_helper"

RSpec.describe "Allocation targets", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it "requires authentication" do
    get "/api/v1/allocation_targets"

    expect(response).to have_http_status(:unauthorized)
  end

  it "creates, lists, updates and replaces destinations" do
    account = create(:reserve_account, user: user)
    post "/api/v1/allocation_targets", params: { name: "Caridade", mode: "percent", percent_bps: 800 }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    expect(json["data"]).to include("name" => "Caridade", "mode" => "percent", "percent_bps" => 800, "amount_cents" => nil, "position" => 1)
    id = json.dig("data", "id")
    post "/api/v1/allocation_targets", params: { name: "Reserva", mode: "remainder", reserve_account_id: account.id }, headers: headers, as: :json
    create(:allocation_target)

    get "/api/v1/allocation_targets", headers: headers
    expect(json["data"].pluck("name")).to eq(%w[Caridade Reserva])
    expect(json.dig("data", 1, "reserve_account_id")).to eq(account.id)

    patch "/api/v1/allocation_targets/#{id}", params: { mode: "fixed", amount_cents: 1_500, percent_bps: nil }, headers: headers, as: :json
    expect(json["data"]).to include("mode" => "fixed", "amount_cents" => 1_500, "percent_bps" => nil)

    put "/api/v1/allocation_targets/#{id}", params: { position: 5 }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "position")).to eq(5)
  end

  it "answers validation errors with stable codes" do
    post "/api/v1/allocation_targets", params: { name: "Viagem", mode: "fixed", percent_bps: 100 }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "amount_cents", 0, "code")).to eq("blank")
    expect(json.dig("error", "details", "percent_bps", 0, "code")).to eq("present")

    target = create(:allocation_target, user: user)
    patch "/api/v1/allocation_targets/#{target.id}", params: { reserve_account_id: create(:reserve_account).id }, headers: headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json.dig("error", "details", "reserve_account_id", 0, "code")).to eq("required")
  end

  it "deletes a destination and keeps the expenses it created" do
    allocation = create(:allocation, user: user)

    delete "/api/v1/allocation_targets/#{allocation.target_id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"]).to eq("deleted_id" => allocation.target_id)
    expect(Allocation.exists?(allocation.id)).to be(false)
    expect(Entry.exists?(allocation.entry_id)).to be(true)
  end

  it "hides other users' destinations" do
    other = create(:allocation_target)

    patch "/api/v1/allocation_targets/#{other.id}", params: { name: "x" }, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)

    delete "/api/v1/allocation_targets/#{other.id}", headers: headers
    expect(response).to have_http_status(:not_found)
  end
end
