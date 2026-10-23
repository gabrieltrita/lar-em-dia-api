require "rails_helper"

RSpec.describe Note do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_length_of(:title).is_at_most(200) }
  it { is_expected.to validate_length_of(:body).is_at_most(10_000) }

  it "squishes the title" do
    expect(build(:note, title: "  Shopping   list ").title).to eq("Shopping list")
  end

  it "encrypts the title and body at rest" do
    note = create(:note, title: "Doctor appointment", body: "Bring the exams")
    row = described_class.connection.select_one("SELECT title, body FROM notes WHERE id = #{described_class.connection.quote(note.id)}")

    expect(row["title"]).not_to include("Doctor")
    expect(row["body"]).not_to include("exams")
    expect(note.reload.body).to eq("Bring the exams")
  end

  it "lists the newest first" do
    user = create(:user)
    older = create(:note, user: user, created_at: 2.days.ago)
    newer = create(:note, user: user)
    expect(user.notes.recent).to eq([ newer, older ])
  end
end
