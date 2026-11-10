require "rails_helper"

RSpec.describe "Unlock from the emailed link", type: :request do
  let(:user) { create(:user) }

  def lock(account)
    User::MAX_FAILED_ATTEMPTS.times { account.register_failed_login! }
    account.reload
  end

  def unlock(token, headers: {})
    post "/api/v1/auth/unlock", params: { token: token }, headers: headers, as: :json
  end

  it "unlocks the account, signs in and audits it" do
    token = lock(user).generate_token_for(:unlock)

    unlock(token)

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "tokens", "access_token")).to be_present
    expect(user.reload).not_to be_access_locked
    expect(user.failed_login_attempts).to eq(0)
    expect(AuditLog.where(action: "auth.unlocked_by_email", target_id: user.id)).to exist
  end

  it "keeps the refresh token in the cookie in cookie mode" do
    unlock(lock(user).generate_token_for(:unlock), headers: { "X-Token-Transport" => "cookie" })

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "tokens", "refresh_token_transport")).to eq("cookie")
    expect(response.headers["Set-Cookie"]).to include(TokenResponder::REFRESH_COOKIE)
  end

  it "still asks for the second factor when 2FA is on" do
    two_factor_user = create(:user, :with_2fa)

    unlock(lock(two_factor_user).generate_token_for(:unlock))

    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "two_factor_required")).to be(true)
    expect(json.dig("data", "challenge_token")).to be_present
    expect(json.dig("data", "tokens")).to be_nil
    expect(two_factor_user.reload).not_to be_access_locked
  end

  it "works only once" do
    token = lock(user).generate_token_for(:unlock)
    unlock(token)

    unlock(token)

    expect(response).to have_http_status(:unauthorized)
    expect(json.dig("error", "code")).to eq("invalid_unlock_token")
  end

  it "stops working when the account is locked again" do
    token = lock(user).generate_token_for(:unlock)
    travel_to(user.locked_until + 1.second) { user.register_failed_login! }

    unlock(token)

    expect(response).to have_http_status(:unauthorized)
    expect(json.dig("error", "code")).to eq("invalid_unlock_token")
  end

  it "stops working once the lock expires" do
    token = lock(user).generate_token_for(:unlock)

    travel_to(user.locked_until + 1.second) { unlock(token) }

    expect(response).to have_http_status(:unauthorized)
    expect(json.dig("error", "code")).to eq("invalid_unlock_token")
  end

  it "rejects an invalid token" do
    unlock("invalid")

    expect(response).to have_http_status(:unauthorized)
    expect(json.dig("error", "code")).to eq("invalid_unlock_token")
  end

  it "rejects an anonymized account" do
    token = lock(user).generate_token_for(:unlock)
    user.update_columns(anonymized_at: Time.current)

    unlock(token)

    expect(response).to have_http_status(:unauthorized)
    expect(json.dig("error", "code")).to eq("invalid_unlock_token")
  end

  it "keeps a deactivated account out" do
    token = lock(user).generate_token_for(:unlock)
    user.update_columns(deactivated_at: Time.current)

    unlock(token)

    expect(response).to have_http_status(:unauthorized)
    expect(json.dig("error", "code")).to eq("invalid_credentials")
  end
end
