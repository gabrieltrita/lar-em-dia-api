require "rails_helper"

RSpec.describe Entry do
  subject { build(:entry) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:category) }
  it { is_expected.to validate_presence_of(:description) }
  it { is_expected.to validate_length_of(:description).is_at_most(200) }
  it { is_expected.to validate_presence_of(:amount_cents) }
  it { is_expected.to validate_numericality_of(:amount_cents).only_integer.is_greater_than(0) }
  it { is_expected.to validate_presence_of(:due_on) }

  it "encrypts the description" do
    entry = create(:entry, description: "Freelance for Acme")

    stored = described_class.connection.select_value("SELECT description FROM entries WHERE id = #{described_class.connection.quote(entry.id)}")
    expect(stored).not_to include("Acme")
    expect(entry.reload.description).to eq("Freelance for Acme")
  end

  it "takes its kind from the category" do
    entry = create(:entry, category: create(:category, :expense))

    expect(entry).to be_expense
  end

  it "requires a category to have a kind" do
    entry = build(:entry, category: nil)

    expect(entry).not_to be_valid
    expect(entry.errors.details[:kind]).to include(error: :inclusion, value: nil)
  end

  it "starts pending and rejects an unknown status" do
    expect(build(:entry)).to be_pending
    expect(build(:entry, status: "late")).not_to be_valid
  end

  it "only accepts paid_on when paid" do
    expect(build(:entry, :paid)).to be_valid

    entry = build(:entry, paid_on: Date.current)
    expect(entry).not_to be_valid
    expect(entry.errors[:paid_on]).to eq([ "can only be set when the entry is paid" ])
  end

  it "rejects an inactive category for new entries but keeps existing ones valid" do
    category = create(:category)
    existing = create(:entry, category: category)
    category.update!(active: false)

    expect(existing.reload.update(description: "Renamed")).to be(true)

    entry = build(:entry, category: category)
    expect(entry).not_to be_valid
    expect(entry.errors.details[:category]).to include(error: :inactive)
  end

  it "lists by due date, then creation" do
    user = create(:user)
    later = create(:entry, user: user, due_on: Date.current + 1)
    first = create(:entry, user: user, due_on: Date.current, created_at: 1.hour.ago)
    second = create(:entry, user: user, due_on: Date.current)

    expect(user.entries.chronological).to eq([ first, second, later ])
  end
end
