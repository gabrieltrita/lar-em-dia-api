require "rails_helper"

RSpec.describe "Login, bloqueio e 2FA", type: :request do
  let(:password) { "Senha@123" }
  let!(:user) { create(:user, email: "login@example.com", password: password) }

  describe "POST /api/v1/auth/login" do
    it "autentica com credenciais válidas" do
      login("LOGIN@example.com", password)
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "tokens", "token_type")).to eq("Bearer")
      expect(user.reload.sign_in_count).to eq(1)
      expect(AuditLog.where(action: "auth.login", target_id: user.id)).to exist
    end

    it "rejeita senha errada e e-mail inexistente com a mesma resposta" do
      login("login@example.com", "Errada@123")
      wrong_password = [ response.status, json ]
      login("nao@existe.com", password)

      expect([ response.status, json ]).to eq(wrong_password)
      expect(response).to have_http_status(:unauthorized)
    end

    it "exige e-mail confirmado (só depois de acertar a senha)" do
      create(:user, :unconfirmed, email: "pendente@example.com", password: password)

      login("pendente@example.com", "Errada@123")
      expect(response).to have_http_status(:unauthorized)

      login("pendente@example.com", password)
      expect(response).to have_http_status(:forbidden)
      expect(json.dig("error", "code")).to eq("email_not_confirmed")
    end
  end

  describe "bloqueio progressivo" do
    it "após 5 erros bloqueia — até a senha certa é recusada — com a mesma mensagem" do
      5.times { login("login@example.com", "Errada@123") }
      expect(user.reload).to be_access_locked

      login("login@example.com", password)
      expect(response).to have_http_status(:unauthorized)
      expect(json.dig("error", "message")).to eq("E-mail ou senha inválidos")

      travel 16.minutes do
        login("login@example.com", password)
        expect(response).to have_http_status(:ok)
        expect(user.reload.failed_login_attempts).to eq(0)
      end
    end
  end

  describe "2FA" do
    let!(:user) { create(:user, :with_2fa, email: "dois@example.com", password: password) }

    it "pede o segundo fator e só emite tokens com código válido" do
      login("dois@example.com", password)
      expect(json.dig("data", "two_factor_required")).to be(true)
      expect(json.dig("data", "tokens")).to be_nil
      challenge = json.dig("data", "challenge_token")

      post "/api/v1/auth/two_factor", params: { challenge_token: challenge, code: "000000" }, as: :json
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/auth/two_factor", params: { challenge_token: challenge, code: otp_code(user) }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "tokens", "access_token")).to be_present

      # desafio é de uso único
      travel 31.seconds do
        post "/api/v1/auth/two_factor", params: { challenge_token: challenge, code: otp_code(user) }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "challenge_token não funciona como access token" do
      login("dois@example.com", password)
      get "/api/v1/me", headers: bearer(json.dig("data", "challenge_token"))
      expect(response).to have_http_status(:unauthorized)
    end

    it "códigos errados contam para o bloqueio" do
      login("dois@example.com", password)
      challenge = json.dig("data", "challenge_token")
      5.times { post "/api/v1/auth/two_factor", params: { challenge_token: challenge, code: "123456" }, as: :json }

      expect(user.reload).to be_access_locked
    end

    it "aceita código de backup" do
      codes = user.regenerate_backup_codes!
      login("dois@example.com", password)
      post "/api/v1/auth/two_factor", params: { challenge_token: json.dig("data", "challenge_token"), code: codes.first }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
