require "rails_helper"

RSpec.describe InvestmentPosition do
  subject { create(:investment_position) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:asset) }
  it { is_expected.to have_many(:transactions).dependent(:destroy) }

  it "allows one position per asset and user" do
    duplicate = build(:investment_position, user: subject.user, asset: subject.asset)

    expect(duplicate).not_to be_valid
    expect(build(:investment_position, asset: subject.asset)).to be_valid
  end

  it "starts FIIs with the income goal and stocks with the growth goal" do
    expect(create(:investment_position, asset: create(:asset, :fii)).goal).to eq("income")
    expect(create(:investment_position, asset: create(:asset)).goal).to eq("growth")
  end

  it "keeps a chosen goal and rejects an unknown one" do
    expect(create(:investment_position, asset: create(:asset, :fii), goal: :growth).goal).to eq("growth")
    expect(build(:investment_position, goal: "speculation")).not_to be_valid
    expect(build(:investment_position, asset: nil)).not_to be_valid
  end

  it "uses the ticker of its asset" do
    expect(subject.ticker).to eq(subject.asset.ticker)
  end
end
