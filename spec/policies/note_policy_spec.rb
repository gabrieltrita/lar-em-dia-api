require "rails_helper"

RSpec.describe NotePolicy do
  let(:owner) { create(:user) }
  let(:note) { create(:note, user: owner) }

  it "lets the owner do everything" do
    policy = described_class.new(owner, note)
    expect([ policy.index?, policy.create?, policy.show?, policy.update?, policy.destroy? ]).to all(be(true))
  end

  it "keeps other users and admins away from the note" do
    [ create(:user), create(:user, :admin) ].each do |other|
      policy = described_class.new(other, note)
      expect([ policy.show?, policy.update?, policy.destroy? ]).to all(be(false))
    end
  end

  it "scopes the list to the user's own notes" do
    note
    create(:note)
    expect(described_class::Scope.new(owner, Note).resolve).to contain_exactly(note)
  end
end
