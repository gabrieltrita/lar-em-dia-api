require "rails_helper"

RSpec.describe "Notes (example module)", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:other_note) { create(:note) }

  it "requires authentication" do
    get "/api/v1/notes"
    expect(response).to have_http_status(:unauthorized)
  end

  describe "POST /api/v1/notes" do
    it "creates a note owned by the current user, ignoring any user_id sent" do
      post "/api/v1/notes", params: { title: "Groceries", body: "Milk", user_id: other_note.user_id }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(json["data"]).to include("title" => "Groceries", "body" => "Milk")
      expect(json["data"]).not_to have_key("user_id")
      expect(Note.find(json.dig("data", "id")).user).to eq(user)
    end

    it "returns per-field errors" do
      post "/api/v1/notes", params: { title: "", body: "x" * 10_001 }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("error", "details", "title", 0, "code")).to eq("blank")
      expect(json.dig("error", "details", "body", 0, "code")).to eq("too_long")
    end
  end

  describe "GET /api/v1/notes" do
    it "lists only the user's notes, newest first, paginated" do
      older = create(:note, user: user, created_at: 1.day.ago)
      newer = create(:note, user: user)
      other_note

      get "/api/v1/notes", params: { limit: 1 }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(json["data"].map { |n| n["id"] }).to eq([ newer.id ])
      expect(json["meta"]).to include("page" => 1, "per_page" => 1, "total" => 2, "next" => 2)

      get "/api/v1/notes", params: { page: 2, limit: 1 }, headers: headers
      expect(json["data"].map { |n| n["id"] }).to eq([ older.id ])
    end
  end

  describe "a single note" do
    let(:note) { create(:note, user: user, title: "Mine") }

    it "shows the owner's note" do
      get "/api/v1/notes/#{note.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "title")).to eq("Mine")
    end

    it "updates with PATCH and PUT" do
      patch "/api/v1/notes/#{note.id}", params: { title: "Renamed" }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(json.dig("data", "title")).to eq("Renamed")

      put "/api/v1/notes/#{note.id}", params: { body: "New body" }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(note.reload.body).to eq("New body")
    end

    it "rejects an invalid update" do
      patch "/api/v1/notes/#{note.id}", params: { title: "" }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(note.reload.title).to eq("Mine")
    end

    it "deletes the owner's note" do
      delete "/api/v1/notes/#{note.id}", headers: headers
      expect(response).to have_http_status(:no_content)
      expect(Note.exists?(note.id)).to be(false)
    end
  end

  describe "another user's note" do
    it "answers 404 to every action and leaves the note untouched" do
      get "/api/v1/notes/#{other_note.id}", headers: headers
      expect(response).to have_http_status(:not_found)
      expect(json.dig("error", "code")).to eq("not_found")

      patch "/api/v1/notes/#{other_note.id}", params: { title: "Hacked" }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)

      delete "/api/v1/notes/#{other_note.id}", headers: headers
      expect(response).to have_http_status(:not_found)

      expect(other_note.reload.title).not_to eq("Hacked")
    end

    it "is hidden even from admins" do
      get "/api/v1/notes/#{other_note.id}", headers: auth_headers(create(:user, :admin))
      expect(response).to have_http_status(:not_found)
    end
  end

  it "keeps note content out of the logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    expect(filter.filter("title" => "Secret", "body" => "Secret")).to eq("title" => "[FILTERED]", "body" => "[FILTERED]")
  end
end
