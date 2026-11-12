require "rails_helper"

RSpec.describe AssetPolicy do
  let(:user) { create(:user) }

  it "lets any user list and show assets" do
    expect(described_class.new(user, Asset).index?).to be(true)
    expect(described_class.new(user, build(:asset)).show?).to be(true)
  end

  it "scopes to every asset, including inactive ones" do
    assets = [ create(:asset), create(:asset, :inactive) ]

    expect(described_class::Scope.new(user, Asset).resolve).to match_array(assets)
  end
end
