require "rails_helper"

RSpec.describe "Admin::Categories", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:headers) { auth_headers(admin) }
  let!(:groceries) { create(:category, :expense, key: "groceries", name: "Groceries", position: 1, default_nature: :variable) }
  let!(:old) { create(:category, :expense, :inactive, key: "old_stuff", name: "Old stuff", position: 2, default_nature: :fixed) }
  let!(:salary) { create(:category, key: "salary", name: "Salary", position: 0) }

  describe "GET /api/v1/admin/categories" do
    it "lists every category, inactive ones included, and filters by kind" do
      get "/api/v1/admin/categories", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["data"].pluck("key")).to eq(%w[groceries old_stuff salary])
      expect(json["data"].second).to include("active" => false, "default_nature" => "fixed")

      get "/api/v1/admin/categories", params: { kind: "income" }, headers: headers
      expect(json["data"].pluck("key")).to eq(%w[salary])
    end

    it "is only for admins" do
      get "/api/v1/admin/categories", headers: auth_headers(create(:user))
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/admin/categories" do
    let(:params) { { kind: "expense", key: "daycare", name: "Creche", position: 5, default_nature: "fixed" } }

    it "creates a category and audits it" do
      post "/api/v1/admin/categories", params: params, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("key" => "daycare", "name" => "Creche", "active" => true, "default_nature" => "fixed")
      log = AuditLog.find_by(action: "category.created")
      expect(log).to have_attributes(target_type: "Category", target_id: json.dig("data", "id"), actor_id: admin.id)
      expect(log.metadata).to eq("key" => "daycare", "kind" => "expense")

      get "/api/v1/categories", params: { kind: "expense" }, headers: auth_headers(create(:user))
      expect(json["data"].pluck("key")).to include("daycare")
    end

    it "validates the key and the nature" do
      post "/api/v1/admin/categories", params: params.merge(key: "groceries", default_nature: nil), headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "key", 0, "code")).to eq("taken")
      expect(json.dig("error", "details", "default_nature", 0, "code")).to eq("blank")
    end

    it "is only for admins" do
      post "/api/v1/admin/categories", params: params, headers: auth_headers(create(:user)), as: :json
      expect(response).to have_http_status(:forbidden)
      expect(Category.exists?(key: "daycare")).to be(false)
    end
  end

  describe "PATCH /api/v1/admin/categories/:id" do
    it "renames, reorders and deactivates, keeping the entries" do
      entry = create(:entry, category: groceries)

      patch "/api/v1/admin/categories/#{groceries.id}", params: { name: "Supermarket", position: 3, active: false }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to include("name" => "Supermarket", "position" => 3, "active" => false)
      expect(entry.reload.category).to eq(groceries)
      expect(AuditLog.find_by(action: "category.updated").metadata).to eq("key" => "groceries", "fields" => %w[name position active])
    end

    it "does not audit a change that changes nothing" do
      patch "/api/v1/admin/categories/#{groceries.id}", params: { name: "Groceries" }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(AuditLog.where(action: "category.updated")).to be_empty
    end

    it "keeps the key and the kind" do
      patch "/api/v1/admin/categories/#{groceries.id}", params: { key: "food", kind: "income" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "key", 0, "code")).to eq("immutable")
      expect(json.dig("error", "details", "kind", 0, "code")).to eq("immutable")
      expect(groceries.reload.key).to eq("groceries")
    end

    it "answers 404 for an unknown category and 403 for non-admins" do
      patch "/api/v1/admin/categories/#{SecureRandom.uuid}", params: { name: "X" }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)

      patch "/api/v1/admin/categories/#{groceries.id}", params: { name: "X" }, headers: auth_headers(create(:user)), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /api/v1/admin/categories/:id" do
    it "works as PATCH" do
      put "/api/v1/admin/categories/#{old.id}", params: { active: true }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(old.reload).to be_active

      put "/api/v1/admin/categories/#{old.id}", params: { name: "" }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      put "/api/v1/admin/categories/#{SecureRandom.uuid}", params: { name: "X" }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)

      put "/api/v1/admin/categories/#{old.id}", params: { name: "X" }, headers: auth_headers(create(:user)), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
