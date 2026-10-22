require "rails_helper"

RSpec.describe "Admin::AuditLogs", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  it "lists and filters the audit trail" do
    AuditLog.record!("auth.login", target: user, actor: user)
    AuditLog.record!("user.role_changed", target: user, actor: admin, metadata: { from: "user", to: "admin" })

    get "/api/v1/admin/audit_logs", params: { action_name: "user.role_changed" }, headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    expect(json["data"].map { |l| l["action"] }).to eq([ "user.role_changed" ])
    expect(json["data"].first["actor_id"]).to eq(admin.id)

    get "/api/v1/admin/audit_logs", params: { target_id: user.id }, headers: auth_headers(admin)
    expect(json.dig("meta", "total")).to eq(2)
  end

  it "is admin only" do
    get "/api/v1/admin/audit_logs", headers: auth_headers(user)
    expect(response).to have_http_status(:forbidden)
  end

  it "keeps records immutable" do
    log = AuditLog.record!("auth.login", target: user, actor: user)
    expect { log.update!(action: "auth.logout") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
