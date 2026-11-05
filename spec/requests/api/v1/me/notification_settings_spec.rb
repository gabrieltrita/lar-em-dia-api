require "rails_helper"

RSpec.describe "Notification settings", type: :request do
  let(:user) { create(:user) }

  describe "GET /api/v1/me/notification_settings" do
    it "starts with alerts on, one day before" do
      get "/api/v1/me/notification_settings", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to eq("due_alerts_enabled" => true, "due_alert_days_before" => 1)
    end
  end

  describe "PATCH /api/v1/me/notification_settings" do
    it "updates the preferences and audits the change" do
      patch "/api/v1/me/notification_settings", params: { due_alerts_enabled: false, due_alert_days_before: 3 }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to eq("due_alerts_enabled" => false, "due_alert_days_before" => 3)
      log = AuditLog.find_by(action: "user.notification_settings_changed")
      expect(log.metadata).to eq("fields" => %w[due_alerts_enabled due_alert_days_before], "via" => "settings")
    end

    it "accepts PUT and does not audit when nothing changed" do
      put "/api/v1/me/notification_settings", params: { due_alert_days_before: 1 }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(AuditLog.where(action: "user.notification_settings_changed")).to be_empty
    end

    it "rejects days outside 0 to 7 and a missing switch" do
      patch "/api/v1/me/notification_settings", params: { due_alerts_enabled: nil, due_alert_days_before: 8 }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "due_alert_days_before", 0, "code")).to eq("inclusion")
      expect(json.dig("error", "details", "due_alerts_enabled", 0, "code")).to eq("inclusion")
    end

    it "rejects invalid days with PUT too" do
      put "/api/v1/me/notification_settings", params: { due_alert_days_before: -1 }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /api/v1/me/notification_settings/unsubscribe" do
    it "turns the alerts off without a login" do
      token = user.generate_token_for(:due_alerts_unsubscribe)

      post "/api/v1/me/notification_settings/unsubscribe", params: { token: token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "due_alerts_enabled")).to be(false)
      expect(user.reload.due_alerts_enabled).to be(false)
      expect(AuditLog.find_by(action: "user.notification_settings_changed").metadata["via"]).to eq("unsubscribe_link")
    end

    it "rejects a bad, expired or anonymized link" do
      token = user.generate_token_for(:due_alerts_unsubscribe)
      post "/api/v1/me/notification_settings/unsubscribe", params: { token: "nope" }, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(json.dig("error", "code")).to eq("invalid_unsubscribe_token")

      travel(61.days) { post "/api/v1/me/notification_settings/unsubscribe", params: { token: token }, as: :json }
      expect(response).to have_http_status(:unauthorized)

      user.anonymize!
      post "/api/v1/me/notification_settings/unsubscribe", params: { token: token }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
