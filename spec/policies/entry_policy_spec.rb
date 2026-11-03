require "rails_helper"

RSpec.describe EntryPolicy do
  let(:owner) { create(:user) }
  let(:entry) { create(:entry, user: owner) }

  it "lets the owner do everything" do
    policy = described_class.new(owner, entry)
    expect([ policy.index?, policy.create?, policy.show?, policy.update?, policy.destroy? ]).to all(be(true))
  end

  it "keeps other users and admins away" do
    [ create(:user), create(:user, :admin) ].each do |other|
      policy = described_class.new(other, entry)
      expect([ policy.show?, policy.update?, policy.destroy? ]).to all(be(false))
    end
  end

  it "scopes the list to the user's own records" do
    entry
    create(:entry)
    expect(described_class::Scope.new(owner, Entry).resolve).to contain_exactly(entry)
  end
end
