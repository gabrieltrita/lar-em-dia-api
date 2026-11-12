require "rails_helper"

RSpec.describe FundReport do
  subject { create(:fund_report) }

  it { is_expected.to belong_to(:asset) }
  it { is_expected.to validate_uniqueness_of(:reference_month).scoped_to(:asset_id) }
  it { is_expected.to validate_numericality_of(:shares_count).only_integer }

  it "is the asset's latest report by month" do
    newer = create(:fund_report, asset: subject.asset, reference_month: Date.new(2026, 10, 1))

    expect(subject.asset.reload.latest_fund_report).to eq(newer)
  end
end
