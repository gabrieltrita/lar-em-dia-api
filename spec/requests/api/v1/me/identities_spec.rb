require "rails_helper"

RSpec.describe "Me::Identities", type: :request do
  let(:user) { create(:user) }

  describe "GET /api/v1/me/identities" do
    it "lists the linked identities without the provider uid" do
      create(:identity, user: user, provider: :google, email_at_link: "me@gmail.com")
      create(:identity, provider: :apple)

      get "/api/v1/me/identities", headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json["data"].size).to eq(1)
      expect(json["data"].first).to include("provider" => "google", "email_at_link" => "me@gmail.com")
      expect(json["data"].first.keys).not_to include("provider_uid")
    end

    it "requires authentication" do
      get "/api/v1/me/identities"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/me/identities/:id" do
    let!(:identity) { create(:identity, user: user) }

    it "unlinks the identity after the password check and audits it" do
      delete "/api/v1/me/identities/#{identity.id}", params: { current_password: "Senha@123" }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:no_content)
      expect(Identity.exists?(identity.id)).to be(false)
      log = AuditLog.find_by(action: "identity.unlinked", target_id: user.id)
      expect(log.metadata).to eq("provider" => "google")
    end

    it "keeps the identity when the password is wrong" do
      delete "/api/v1/me/identities/#{identity.id}", params: { current_password: "Errada@123" }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]["code"]).to eq("invalid_current_password")
      expect(Identity.exists?(identity.id)).to be(true)
    end

    it "does not touch another user's identity" do
      stranger = create(:identity)

      delete "/api/v1/me/identities/#{stranger.id}", params: { current_password: "Senha@123" }, headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:not_found)
      expect(Identity.exists?(stranger.id)).to be(true)
    end

    context "without a password" do
      let(:user) { create(:user, :passwordless, :with_2fa) }
      let(:identity) { user.identities.first }

      it "refuses to remove the only way to log in" do
        delete "/api/v1/me/identities/#{identity.id}", params: { code: otp_code(user) }, headers: auth_headers(user), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]["code"]).to eq("last_login_method")
        expect(Identity.exists?(identity.id)).to be(true)
      end

      it "unlinks one identity while another remains, re-authenticating with the 2FA code" do
        create(:identity, user: user, provider: :apple)

        delete "/api/v1/me/identities/#{identity.id}", params: { code: otp_code(user) }, headers: auth_headers(user), as: :json

        expect(response).to have_http_status(:no_content)
        expect(user.identities.reload.map(&:provider)).to eq([ "apple" ])
      end

      it "rejects a wrong 2FA code" do
        create(:identity, user: user, provider: :apple)

        delete "/api/v1/me/identities/#{identity.id}", params: { code: "000000" }, headers: auth_headers(user), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]["code"]).to eq("invalid_two_factor_code")
      end
    end

    context "without a password and without 2FA" do
      let(:user) { create(:user, :passwordless) }
      let(:identity) { user.identities.first }

      it "cannot re-authenticate yet" do
        create(:identity, user: user, provider: :apple)

        delete "/api/v1/me/identities/#{identity.id}", headers: auth_headers(user), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]["code"]).to eq("reauthentication_unavailable")
      end
    end
  end
end
