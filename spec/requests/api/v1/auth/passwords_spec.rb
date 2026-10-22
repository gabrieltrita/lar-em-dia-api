require "rails_helper"

RSpec.describe "Password recovery", type: :request do
  let!(:user) { create(:user, email: "reset@example.com") }

  it "answers 202 for an unknown email without sending anything" do
    expect {
      post "/api/v1/auth/password/forgot", params: { email: "ninguem@example.com" }, as: :json
    }.not_to have_enqueued_mail(UserMailer, :password_reset)
    expect(response).to have_http_status(:accepted)
  end

  it "enqueues the mail job with only the user so the token never reaches Redis or logs" do
    post "/api/v1/auth/password/forgot", params: { email: "reset@example.com" }, as: :json

    job = enqueued_jobs.find { |j| j["job_class"] == "ActionMailer::MailDeliveryJob" }
    expect(job).to be_present
    serialized = job["arguments"].to_json
    expect(serialized).to include(user.to_global_id.to_s)
    expect(serialized).not_to match(/[A-Za-z0-9_-]{60,}/)
  end

  it "emails a link with a valid token" do
    mail = UserMailer.password_reset(user)
    token = CGI.unescape(mail.text_part.body.to_s[/token=([^\s]+)/, 1])
    expect(User.find_by_token_for(:password_reset, token)).to eq(user)
  end

  it "resets the password, unlocks the account and the token is single use" do
    5.times { user.register_failed_login! }
    token = user.generate_token_for(:password_reset)

    post "/api/v1/auth/password/reset", params: { token: token, password: "Nova@1234", password_confirmation: "Nova@1234" }, as: :json
    expect(response).to have_http_status(:ok)
    user.reload
    expect(user.authenticate("Nova@1234")).to be_truthy
    expect(user).not_to be_access_locked

    post "/api/v1/auth/password/reset", params: { token: token, password: "Outra@1234", password_confirmation: "Outra@1234" }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "confirms the email of users who had not confirmed yet" do
    pending_user = create(:user, :unconfirmed)
    post "/api/v1/auth/password/reset",
      params: { token: pending_user.generate_token_for(:password_reset), password: "Nova@1234", password_confirmation: "Nova@1234" }, as: :json
    expect(pending_user.reload).to be_confirmed
  end

  it "rejects a weak password" do
    post "/api/v1/auth/password/reset", params: { token: user.generate_token_for(:password_reset), password: "fraca" }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end
end
