require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it "requires authentication" do
    get "/api/v1/categories"
    expect(response).to have_http_status(:unauthorized)
  end

  it "lists the active categories by kind and position" do
    salary = create(:category, key: "salary", position: 0)
    bonus = create(:category, key: "bonus", position: 1)
    rent = create(:category, :expense, key: "rent")
    create(:category, :inactive, key: "old")

    get "/api/v1/categories", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json["data"].map { |category| category["id"] }).to eq([ rent.id, salary.id, bonus.id ])
    expect(json["data"].last).to include("kind" => "income", "key" => "bonus", "name" => "Category", "position" => 1)
    expect(json["data"].first).to include("kind" => "expense", "default_nature" => "variable", "custom" => false)
  end

  it "lists the user's own categories after the global ones and hides other users' categories" do
    global = create(:category, :expense)
    own = create(:category, :expense, user: user, name: "Pet")
    create(:category, :expense, user: create(:user))

    get "/api/v1/categories", headers: headers

    expect(json["data"].pluck("id")).to eq([ global.id, own.id ])
    expect(json["data"].last).to include("name" => "Pet", "custom" => true)
  end

  describe "POST /api/v1/categories" do
    it "creates one of the user's own categories" do
      post "/api/v1/categories", params: { kind: "expense", name: "Pet", default_nature: "variable", key: "salary" }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("kind" => "expense", "name" => "Pet", "default_nature" => "variable", "custom" => true, "position" => 1)
      expect(json.dig("data", "key")).to start_with("custom_")
      expect(user.categories.count).to eq(1)
    end

    it "validates the name, the nature and the limit" do
      post "/api/v1/categories", params: { kind: "income", name: "", default_nature: "fixed" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "name", 0, "code")).to eq("blank")
      expect(json.dig("error", "details", "default_nature", 0, "code")).to eq("only_for_expenses")

      stub_const("Category::MAX_PER_USER", 0)
      post "/api/v1/categories", params: { kind: "income", name: "Freelance" }, headers: headers, as: :json
      expect(json.dig("error", "details", "base", 0, "code")).to eq("too_many_categories")
    end
  end

  describe "PATCH /api/v1/categories/:id" do
    let(:category) { create(:category, :expense, user: user, name: "Pet") }

    it "renames the category and changes its default nature, keeping the key and kind" do
      patch "/api/v1/categories/#{category.id}", params: { name: "Pets", default_nature: "fixed", kind: "income", key: "x" }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["data"]).to include("name" => "Pets", "default_nature" => "fixed", "kind" => "expense", "key" => category.key)
    end

    it "validates the changes" do
      patch "/api/v1/categories/#{category.id}", params: { name: "" }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "name", 0, "code")).to eq("blank")
    end

    it "answers 404 for global categories and other users' categories" do
      [ create(:category), create(:category, user: create(:user)) ].each do |other|
        patch "/api/v1/categories/#{other.id}", params: { name: "Mine" }, headers: headers, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    it "works as PUT" do
      put "/api/v1/categories/#{category.id}", params: { name: "Animals" }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "name")).to eq("Animals")
    end
  end

  describe "DELETE /api/v1/categories/:id" do
    let(:category) { create(:category, :expense, user: user) }

    it "deletes an unused category" do
      delete "/api/v1/categories/#{category.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "deleted_id")).to eq(category.id)
      expect(Category.exists?(category.id)).to be(false)
    end

    it "refuses a category that entries still use" do
      create(:entry, user: user, category: category)

      delete "/api/v1/categories/#{category.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "code")).to eq("category_in_use")
      expect(Category.exists?(category.id)).to be(true)
    end

    it "answers 404 for a global category" do
      delete "/api/v1/categories/#{create(:category).id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  it "filters by kind and ignores an unknown kind" do
    income = create(:category)
    expense = create(:category, :expense)

    get "/api/v1/categories", params: { kind: "income" }, headers: headers
    expect(json["data"].map { |category| category["id"] }).to eq([ income.id ])

    get "/api/v1/categories", params: { kind: "transfer" }, headers: headers
    expect(json["data"].map { |category| category["id"] }).to contain_exactly(income.id, expense.id)
  end
end
