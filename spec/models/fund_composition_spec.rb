require "rails_helper"

RSpec.describe FundComposition do
  subject { create(:fund_composition) }

  it { is_expected.to belong_to(:asset) }
  it { is_expected.to validate_presence_of(:reference_on) }
  it { is_expected.to validate_uniqueness_of(:asset_id).case_insensitive }

  it "is removed with the asset, together with its properties" do
    create(:fund_property, fund_composition: subject)

    expect { subject.asset.destroy! }.to change(FundProperty, :count).by(-1).and change(described_class, :count).by(-1)
  end
end
