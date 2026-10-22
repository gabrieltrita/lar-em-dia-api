require "rails_helper"

RSpec.describe "Me::Sessions", type: :request do
  let(:user) { create(:user) }

  it "lists one row per device and flags the current session" do
    current = tokens_for(user)
    other = tokens_for(user)
    post "/api/v1/auth/refresh", params: { refresh_token: other[:refresh_token] }, as: :json

    get "/api/v1/me/sessions", headers: bearer(current[:access_token])
    expect(response).to have_http_status(:ok)
    expect(json["data"].size).to eq(2)
    expect(json["data"].count { |s| s["current"] }).to eq(1)
    expect(json["data"].first.keys).to include("id", "user_agent", "ip_address", "started_at", "last_activity_at")
  end

  it "ends another device immediately (access and refresh)" do
    current = tokens_for(user)
    other = tokens_for(user)
    other_id = RefreshToken.find_by_raw_token(other[:refresh_token]).family_id

    delete "/api/v1/me/sessions/#{other_id}", headers: bearer(current[:access_token])
    expect(response).to have_http_status(:no_content)

    get "/api/v1/me", headers: bearer(other[:access_token])
    expect(response).to have_http_status(:unauthorized)
    post "/api/v1/auth/refresh", params: { refresh_token: other[:refresh_token] }, as: :json
    expect(response).to have_http_status(:unauthorized)

    get "/api/v1/me", headers: bearer(current[:access_token])
    expect(response).to have_http_status(:ok)
  end

  it "does not allow ending another user's session" do
    stranger = create(:user)
    stranger_id = RefreshToken.find_by_raw_token(tokens_for(stranger)[:refresh_token]).family_id

    delete "/api/v1/me/sessions/#{stranger_id}", headers: auth_headers(user)
    expect(response).to have_http_status(:not_found)
  end
end
