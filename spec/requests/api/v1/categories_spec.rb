require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:headers) { auth_headers(create(:user)) }

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
    expect(json["data"].first).to include("kind" => "expense", "default_nature" => "variable")
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
