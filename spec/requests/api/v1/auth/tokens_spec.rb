require "rails_helper"

RSpec.describe "Tokens, sessões e logout", type: :request do
  let(:user) { create(:user) }

  describe "rotas protegidas" do
    it "exige token" do
      get "/api/v1/me"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejeita token inválido" do
      get "/api/v1/me", headers: bearer("abc.def.ghi")
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejeita refresh token usado como access token" do
      get "/api/v1/me", headers: bearer(tokens_for(user)[:refresh_token])
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejeita token expirado" do
      headers = auth_headers(user)
      travel 16.minutes do
        get "/api/v1/me", headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "rejeita token assinado com outro segredo" do
      forged = JWT.encode({ sub: user.id, type: "access", iss: "trita-api", exp: 1.hour.from_now.to_i, iat: Time.current.to_i, jti: "x" }, "outro-segredo", "HS256")
      get "/api/v1/me", headers: bearer(forged)
      expect(response).to have_http_status(:unauthorized)
    end

    it "aceita tokens do segredo anterior durante a rotação (JWT_SECRET_PREVIOUS)" do
      old_secret = ENV.fetch("JWT_SECRET")
      token = tokens_for(user)[:access_token]

      begin
        ENV["JWT_SECRET_PREVIOUS"] = old_secret
        ENV["JWT_SECRET"] = SecureRandom.hex(64)
        get "/api/v1/me", headers: bearer(token)
        expect(response).to have_http_status(:ok)
      ensure
        ENV["JWT_SECRET"] = old_secret
        ENV.delete("JWT_SECRET_PREVIOUS")
      end
    end
  end

  describe "POST /api/v1/auth/refresh" do
    it "rotaciona o refresh token mantendo a mesma sessão" do
      old = tokens_for(user)[:refresh_token]
      family = RefreshToken.find_by_raw_token(old).family_id

      post "/api/v1/auth/refresh", params: { refresh_token: old }, as: :json
      expect(response).to have_http_status(:ok)
      new_token = json.dig("data", "tokens", "refresh_token")
      expect(new_token).not_to eq(old)
      expect(RefreshToken.find_by_raw_token(new_token).family_id).to eq(family)
    end

    it "detecta reuso e derruba todas as sessões (inclusive access tokens)" do
      tokens = tokens_for(user)
      post "/api/v1/auth/refresh", params: { refresh_token: tokens[:refresh_token] }, as: :json
      new_tokens = json.dig("data", "tokens")

      post "/api/v1/auth/refresh", params: { refresh_token: tokens[:refresh_token] }, as: :json
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/auth/refresh", params: { refresh_token: new_tokens["refresh_token"] }, as: :json
      expect(response).to have_http_status(:unauthorized)

      get "/api/v1/me", headers: bearer(new_tokens["access_token"])
      expect(response).to have_http_status(:unauthorized)
      expect(AuditLog.where(action: "auth.refresh_reuse_detected")).to exist
    end

    it "refresh token antigo não vale depois que o ADMIN troca a senha do usuário" do
      admin = create(:user, :admin)
      tokens = tokens_for(user)

      patch "/api/v1/admin/users/#{user.id}", params: { password: "Trocada@123" }, headers: auth_headers(admin), as: :json
      expect(response).to have_http_status(:ok)

      post "/api/v1/auth/refresh", params: { refresh_token: tokens[:refresh_token] }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "modo cookie (X-Token-Transport: cookie)" do
    let(:cookie_header) { { "X-Token-Transport" => "cookie" } }

    it "entrega o refresh token só em cookie httpOnly e faz refresh pelo cookie" do
      login(user.email, "Senha@123", headers: cookie_header)

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "tokens")).not_to have_key("refresh_token")
      set_cookie = Array(response.headers["Set-Cookie"]).join("\n")
      expect(set_cookie).to match(/trita_refresh=/)
      expect(set_cookie).to match(/httponly/i)
      expect(set_cookie).to match(/samesite=strict/i)
      expect(set_cookie).to include("path=/api/v1/auth")

      post "/api/v1/auth/refresh", headers: cookie_header, as: :json
      expect(response).to have_http_status(:ok)
    end

    it "sem o header customizado o cookie é ignorado (proteção CSRF)" do
      login(user.email, "Senha@123", headers: cookie_header)
      post "/api/v1/auth/refresh", as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    it "encerra a sessão atual na hora (access e refresh)" do
      tokens = tokens_for(user)

      delete "/api/v1/auth/logout", headers: bearer(tokens[:access_token]), as: :json
      expect(response).to have_http_status(:no_content)

      get "/api/v1/me", headers: bearer(tokens[:access_token])
      expect(response).to have_http_status(:unauthorized)

      post "/api/v1/auth/refresh", params: { refresh_token: tokens[:refresh_token] }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "all_devices encerra as outras sessões também" do
      other = tokens_for(user)
      delete "/api/v1/auth/logout", params: { all_devices: true }, headers: auth_headers(user), as: :json

      get "/api/v1/me", headers: bearer(other[:access_token])
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
