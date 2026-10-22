require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  it "bloqueia usuário comum" do
    get "/api/v1/admin/users", headers: auth_headers(user)
    expect(response).to have_http_status(:forbidden)
  end

  it "lista usuários paginados" do
    create_list(:user, 3)
    get "/api/v1/admin/users", params: { limit: 2 }, headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    expect(json["data"].size).to eq(2)
    expect(json.dig("meta", "total")).to eq(4)
  end

  it "filtra por e-mail" do
    target = create(:user, email: "alvo@example.com")
    get "/api/v1/admin/users", params: { email: "alvo@example.com" }, headers: auth_headers(admin)
    expect(json["data"].map { |u| u["id"] }).to eq([ target.id ])
  end

  it "cria um admin" do
    post "/api/v1/admin/users",
      params: { email: "novoadmin@example.com", first_name: "Novo", password: "Admin@123", role: "admin" },
      headers: auth_headers(admin), as: :json
    expect(response).to have_http_status(:created)
    expect(User.find_by(email: "novoadmin@example.com")).to be_admin
  end

  it "promove um usuário a admin" do
    patch "/api/v1/admin/users/#{user.id}", params: { role: "admin" }, headers: auth_headers(admin), as: :json
    expect(response).to have_http_status(:ok)
    expect(user.reload).to be_admin
  end

  it "não deixa o admin rebaixar a si mesmo" do
    patch "/api/v1/admin/users/#{admin.id}", params: { role: "user" }, headers: auth_headers(admin), as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "remove um usuário anonimizando os dados (LGPD)" do
    delete "/api/v1/admin/users/#{user.id}", headers: auth_headers(admin)
    expect(response).to have_http_status(:no_content)
    expect(user.reload).to be_anonymized
  end

  it "exige 2FA ativo do admin" do
    get "/api/v1/admin/users", headers: auth_headers(create(:user, :admin_without_2fa))
    expect(response).to have_http_status(:forbidden)
    expect(json.dig("error", "code")).to eq("two_factor_setup_required")
  end

  it "rejeita role inválida" do
    patch "/api/v1/admin/users/#{user.id}", params: { role: "superuser" }, headers: auth_headers(admin), as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end
end
