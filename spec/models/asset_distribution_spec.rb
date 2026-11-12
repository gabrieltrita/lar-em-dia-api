require "rails_helper"

RSpec.describe AssetDistribution do
  it { is_expected.to belong_to(:asset) }
  it { is_expected.to belong_to(:user).optional }

  it "accepts FII income from CVM without a payment date or user" do
    expect(build(:asset_distribution)).to be_valid
  end

  it "requires a positive whole amount per share" do
    expect(build(:asset_distribution, amount_per_share_e8: 0)).not_to be_valid
    expect(build(:asset_distribution, amount_per_share_e8: 1.5)).not_to be_valid
    expect(build(:asset_distribution, amount_per_share_e8: described_class::MAX_AMOUNT_PER_SHARE_E8 + 1)).not_to be_valid
  end

  it "requires a payment date on or after the record date when recorded by hand" do
    expect(build(:asset_distribution, :manual, paid_on: nil).tap(&:valid?).errors.details[:paid_on]).to include(error: :blank)
    distribution = build(:asset_distribution, :manual, record_on: Date.new(2026, 9, 30), paid_on: Date.new(2026, 9, 29))

    expect(distribution).not_to be_valid
    expect(distribution.errors.details[:paid_on]).to include(error: :before_record_on)
    expect(build(:asset_distribution, :manual, record_on: Date.new(2026, 9, 30), paid_on: Date.new(2026, 9, 30))).to be_valid
  end

  it "accepts only dividends and JCP by hand" do
    expect(build(:asset_distribution, :manual, kind: :jcp)).to be_valid
    expect(build(:asset_distribution, :manual, kind: :fii_income).tap(&:valid?).errors.details[:kind]).to include(a_hash_including(error: :inclusion))
  end

  it "accepts by hand only stocks of the user's portfolio" do
    user = create(:user)
    fii = create(:asset, :fii)
    create(:investment_position, user: user, asset: fii)

    unknown = described_class.new(user: user, asset: create(:asset), source: :manual, kind: :dividend, record_on: Date.current,
      paid_on: Date.current, amount_per_share_e8: 1)
    without_asset = unknown.dup.tap { |distribution| distribution.asset = nil }
    on_fii = unknown.dup.tap { |distribution| distribution.asset = fii }

    expect(unknown.tap(&:valid?).errors.details[:ticker]).to include(error: :unknown_asset)
    expect(without_asset.tap(&:valid?).errors.details[:ticker]).to include(error: :unknown_asset)
    expect(on_fii.tap(&:valid?).errors.details[:ticker]).to include(error: :stock_only)
  end

  it "counts JCP net of the 15% income tax" do
    jcp = build(:asset_distribution, :manual, kind: :jcp, amount_per_share_e8: 33_333_333)

    expect(jcp.net_amount_per_share_e8).to eq(28_333_333)
    expect(build(:asset_distribution, amount_per_share_e8: 33_333_333).net_amount_per_share_e8).to eq(33_333_333)
  end

  it "is paid in the month of the payment date, or the month after the record date without one" do
    expect(build(:asset_distribution, record_on: Date.new(2026, 12, 31)).payment_month).to eq(Date.new(2027, 1, 1))
    expect(build(:asset_distribution, :manual, record_on: Date.new(2026, 9, 30), paid_on: Date.new(2026, 9, 30)).payment_month)
      .to eq(Date.new(2026, 9, 1))
  end

  it "shows CVM records to everyone and manual records only to their owner" do
    cvm = create(:asset_distribution)
    mine = create(:asset_distribution, :manual)
    create(:asset_distribution, :manual)

    expect(described_class.visible_to(mine.user)).to contain_exactly(cvm, mine)
  end

  it "names its asset's ticker" do
    expect(build(:asset_distribution, asset: build(:asset, ticker: "PETR4")).ticker).to eq("PETR4")
    expect(described_class.new.ticker).to be_nil
  end
end
