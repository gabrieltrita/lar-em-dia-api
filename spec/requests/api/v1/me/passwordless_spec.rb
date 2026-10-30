require "rails_helper"

RSpec.describe "Passwordless accounts", type: :request do
  let(:user) { create(:user, :passwordless) }

  it "exposes password_set in the user's own profile" do
    get "/api/v1/me", headers: auth_headers(user)
    expect(json["data"]["password_set"]).to be(false)

    get "/api/v1/me", headers: auth_headers(create(:user))
    expect(json["data"]["password_set"]).to be(true)
  end

  it "answers a password login attempt like any wrong credentials" do
    login(user.email, "Senha@123")

    expect(response).to have_http_status(:unauthorized)
    expect(json["error"]["code"]).to eq("invalid_credentials")
  end

  it "lets the owner start a password reset and set the first password" do
    post "/api/v1/auth/password/forgot", params: { email: user.email }, as: :json
    expect(response).to have_http_status(:accepted)

    post "/api/v1/auth/password/reset",
      params: { token: user.generate_token_for(:password_reset), password: "Nova@12345", password_confirmation: "Nova@12345" }, as: :json
    expect(response).to have_http_status(:ok)
    expect(user.reload.authenticate("Nova@12345")).to be_truthy
  end

  context "with 2FA enabled" do
    let(:user) { create(:user, :passwordless, :with_2fa) }

    it "sets the first password re-authenticating with the 2FA code" do
      patch "/api/v1/me/password", params: { code: otp_code(user), password: "Nova@12345", password_confirmation: "Nova@12345" },
        headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(user.reload).to be_password_set
    end

    it "deletes the account verifying the 2FA code only once" do
      delete "/api/v1/me", params: { code: otp_code(user) }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:no_content)
      expect(user.reload).to be_anonymized
    end
  end

  context "without 2FA" do
    it "cannot re-authenticate sensitive actions yet" do
      patch "/api/v1/me/password", params: { password: "Nova@12345", password_confirmation: "Nova@12345" }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("reauthentication_unavailable")
      expect(user.reload).not_to be_password_set
    end
  end

  it "includes the identities in the data export without the provider uid" do
    get "/api/v1/me/export", headers: auth_headers(user)

    identities = json["content"]["identities"]
    expect(identities.size).to eq(1)
    expect(identities.first).to include("provider" => "google")
    expect(identities.first.keys).not_to include("provider_uid")
  end
end
