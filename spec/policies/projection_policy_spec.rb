require "rails_helper"

RSpec.describe ProjectionPolicy do
  it "lets any user see their projection" do
    expect(described_class.new(create(:user), Projection).show?).to be(true)
  end
end
