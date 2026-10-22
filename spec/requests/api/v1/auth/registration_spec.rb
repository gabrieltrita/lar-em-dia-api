require "rails_helper"

RSpec.describe "Cadastro e confirmação de e-mail", type: :request do
  let(:params) do
    {
      email: "novo@example.com", password: "Senha@123", password_confirmation: "Senha@123",
      first_name: "Novo", last_name: "User", accept_terms: true, accept_privacy: true
    }
  end

  describe "POST /api/v1/auth/register" do
    it "cria conta não confirmada com role user, registra consentimentos e envia confirmação" do
      expect {
        post "/api/v1/auth/register", params: params.merge(role: "admin"), as: :json
      }.to change(User, :count).by(1).and have_enqueued_mail(UserMailer, :confirmation_instructions)

      expect(response).to have_http_status(:accepted)
      expect(json["data"]).not_to have_key("tokens")

      user = User.find_by(email: "novo@example.com")
      expect(user).to be_user
      expect(user).not_to be_confirmed
      expect(Consent.status_for(user).transform_values { |v| v[:granted] }).to eq("terms" => true, "privacy" => true, "marketing" => false)
    end

    it "exige aceite dos termos e da privacidade" do
      post "/api/v1/auth/register", params: params.except(:accept_terms, :accept_privacy), as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details").keys).to include("accept_terms", "accept_privacy")
    end

    context "anti-enumeração" do
      it "e-mail já confirmado: mesma resposta 202 e o dono recebe aviso" do
        create(:user, email: "novo@example.com")

        expect {
          post "/api/v1/auth/register", params: params, as: :json
        }.to have_enqueued_mail(UserMailer, :registration_attempt).and change(User, :count).by(0)

        expect(response).to have_http_status(:accepted)
      end

      it "e-mail cadastrado mas não confirmado: reenvia a confirmação" do
        create(:user, :unconfirmed, email: "novo@example.com")

        expect {
          post "/api/v1/auth/register", params: params, as: :json
        }.to have_enqueued_mail(UserMailer, :confirmation_instructions)
        expect(response).to have_http_status(:accepted)
      end

      it "não revela 'e-mail já em uso' nos erros de validação" do
        create(:user, email: "novo@example.com")
        post "/api/v1/auth/register", params: params.merge(password: "fraca", password_confirmation: "fraca"), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json.dig("error", "details")).not_to have_key("email")
      end
    end
  end

  describe "POST /api/v1/auth/confirm" do
    let(:user) { create(:user, :unconfirmed) }

    it "confirma, envia boas-vindas e já devolve a sessão" do
      token = user.generate_token_for(:email_confirmation)

      expect {
        post "/api/v1/auth/confirm", params: { token: token }, as: :json
      }.to have_enqueued_mail(UserMailer, :welcome)

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "tokens", "access_token")).to be_present
      expect(user.reload).to be_confirmed

      post "/api/v1/auth/confirm", params: { token: token }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejeita token inválido" do
      post "/api/v1/auth/confirm", params: { token: "lixo" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/auth/confirm/resend" do
    it "responde 202 sempre e só envia para conta pendente" do
      create(:user, :unconfirmed, email: "pendente@example.com")
      create(:user, email: "ok@example.com")

      expect { post "/api/v1/auth/confirm/resend", params: { email: "pendente@example.com" }, as: :json }
        .to have_enqueued_mail(UserMailer, :confirmation_instructions)
      expect(response).to have_http_status(:accepted)

      expect { post "/api/v1/auth/confirm/resend", params: { email: "ok@example.com" }, as: :json }
        .not_to have_enqueued_mail(UserMailer, :confirmation_instructions)
      expect(response).to have_http_status(:accepted)
    end
  end
end
