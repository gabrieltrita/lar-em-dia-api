require "rails_helper"

RSpec.describe "Me", type: :request do
  let(:user) { create(:user, password: "Senha@123") }

  it "retorna o perfil" do
    get "/api/v1/me", headers: auth_headers(user)
    expect(response).to have_http_status(:ok)
    expect(json.dig("data", "email")).to eq(user.email)
    expect(json["data"]).not_to have_key("password_digest")
  end

  it "atualiza o perfil mas não permite trocar a role" do
    patch "/api/v1/me", params: { first_name: "Novo", role: "admin" }, headers: auth_headers(user), as: :json
    expect(response).to have_http_status(:ok)
    expect(user.reload.first_name).to eq("Novo")
    expect(user).to be_user
  end

  it "troca a senha e invalida tokens antigos" do
    old_headers = auth_headers(user)
    travel 1.second
    patch "/api/v1/me/password",
      params: { current_password: "Senha@123", password: "Nova@1234", password_confirmation: "Nova@1234" },
      headers: old_headers, as: :json

    expect(response).to have_http_status(:ok)
    new_access = json.dig("data", "tokens", "access_token")

    get "/api/v1/me", headers: old_headers
    expect(response).to have_http_status(:unauthorized)

    get "/api/v1/me", headers: { "Authorization" => "Bearer #{new_access}" }
    expect(response).to have_http_status(:ok)
  end

  it "lista as roles" do
    get "/api/v1/roles", headers: auth_headers(user)
    expect(json["data"].map { |r| r["name"] }).to eq(%w[user admin])
  end
end
