require "rails_helper"

RSpec.describe CategoryPolicy do
  let(:user) { create(:user) }

  it "lets any user list categories and create their own" do
    expect(described_class.new(user, Category).index?).to be(true)
    expect(described_class.new(user, Category.new).create_own?).to be(true)
  end

  it "lets only the owner manage a user category" do
    category = create(:category, user: user)

    expect(described_class.new(user, category).manage_own?).to be(true)
    expect(described_class.new(create(:user), category).manage_own?).to be(false)
  end

  it "scopes the list to active global categories and the user's own" do
    active = create(:category)
    own = create(:category, user: user)
    create(:category, :inactive)
    create(:category, user: create(:user))

    expect(described_class::Scope.new(user, Category).resolve).to contain_exactly(active, own)
  end
end
