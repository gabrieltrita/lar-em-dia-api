require "rails_helper"

RSpec.describe "Account deletion and the Apple token", type: :request do
  include_context "with apple revocation"

  let(:user) { create(:user) }

  before { create(:identity, user: user, provider: :apple, provider_uid: "apple-sub-1") }

  def delete_account(extra = {})
    delete "/api/v1/me", params: { current_password: "Senha@123" }.merge(extra), headers: auth_headers(user), as: :json
  end

  def audit_metadata
    AuditLog.find_by(action: "user.anonymized", target_id: user.id).metadata
  end

  it "revokes the Apple token and audits it" do
    delete_account(apple_authorization_code: "authorization-code", apple_client_id: "com.example.web")

    expect(response).to have_http_status(:no_content)
    expect(user.reload).to be_anonymized
    expect(a_request(:post, apple_revoke_url)).to have_been_made
    expect(audit_metadata).to eq("by" => "self", "apple_token_revoked" => true)
  end

  it "still deletes the account and audits the failure when Apple cannot revoke" do
    stub_request(:post, apple_token_url).to_return(status: 500)

    delete_account(apple_authorization_code: "authorization-code")

    expect(response).to have_http_status(:no_content)
    expect(user.reload).to be_anonymized
    expect(audit_metadata).to eq("by" => "self", "apple_token_revoked" => false)
  end

  it "does not call Apple when the app sends no code" do
    delete_account

    expect(response).to have_http_status(:no_content)
    expect(a_request(:post, apple_token_url)).not_to have_been_made
    expect(audit_metadata).to eq("by" => "self")
  end

  it "does not call Apple for a user without an Apple identity" do
    user.identities.destroy_all

    delete_account(apple_authorization_code: "authorization-code")

    expect(response).to have_http_status(:no_content)
    expect(a_request(:post, apple_token_url)).not_to have_been_made
    expect(audit_metadata).to eq("by" => "self")
  end

  it "keeps the authorization code out of the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    expect(filter.filter("apple_authorization_code" => "authorization-code")).to eq("apple_authorization_code" => "[FILTERED]")
  end
end
