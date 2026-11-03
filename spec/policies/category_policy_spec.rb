require "rails_helper"

RSpec.describe CategoryPolicy do
  it "lets any user list categories" do
    expect(described_class.new(create(:user), Category).index?).to be(true)
  end

  it "scopes the list to active categories" do
    active = create(:category)
    create(:category, :inactive)

    expect(described_class::Scope.new(create(:user), Category).resolve).to contain_exactly(active)
  end
end
