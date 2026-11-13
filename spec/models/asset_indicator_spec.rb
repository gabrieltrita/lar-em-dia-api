require "rails_helper"

RSpec.describe AssetIndicator do
  subject { create(:asset_indicator) }

  it { is_expected.to belong_to(:asset) }
  it { is_expected.to validate_presence_of(:computed_on) }

  it "goes away with its asset" do
    asset = subject.asset

    expect { asset.destroy }.to change(described_class, :count).by(-1)
  end
end
