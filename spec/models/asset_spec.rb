require "rails_helper"

RSpec.describe Asset do
  subject { build(:asset) }

  it { is_expected.to validate_presence_of(:ticker) }
  it { is_expected.to validate_uniqueness_of(:ticker) }
  it { is_expected.to validate_presence_of(:isin) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(100) }
  it { is_expected.to validate_length_of(:sector).is_at_most(100) }
  it { is_expected.to have_many(:quotes).dependent(:destroy) }

  it "accepts B3 tickers of shares, units and FII quotas" do
    %w[PETR4 B3SA3 TAEE11 HGLG11 MRSA3B].each do |ticker|
      expect(build(:asset, ticker: ticker)).to be_valid
    end
  end

  it "rejects tickers outside the B3 format" do
    %w[PETR PETR444 3PET4 petr4 PETR4F].each do |ticker|
      expect(build(:asset, ticker: ticker)).not_to be_valid
    end
  end

  it "validates the ISIN and the CNPJ formats" do
    expect(build(:asset, isin: "BRPETRACNPR6", cnpj: "33000167000101")).to be_valid
    expect(build(:asset, isin: "BRPETRACNPR")).not_to be_valid
    expect(build(:asset, cnpj: "33.000.167/0001-01")).not_to be_valid
  end

  it "rejects an unknown asset type" do
    expect(build(:asset, asset_type: "bdr")).not_to be_valid
  end

  it "returns the most recent quote" do
    asset = create(:asset)
    create(:asset_quote, asset: asset, quoted_on: Date.new(2026, 11, 10))
    latest = create(:asset_quote, asset: asset, quoted_on: Date.new(2026, 11, 11))

    expect(asset.latest_quote).to eq(latest)
  end

  it "lists only active assets" do
    active = create(:asset)
    create(:asset, :inactive)

    expect(described_class.listed).to contain_exactly(active)
  end

  it "searches by ticker prefix or by any part of the name, ignoring case and LIKE wildcards" do
    petrobras = create(:asset, ticker: "PETR4", name: "PETROLEO BRASILEIRO S.A. PETROBRAS")
    recv = create(:asset, ticker: "RECV3", name: "PetroRecôncavo S.A.")
    create(:asset, ticker: "VALE3", name: "VALE S.A.")

    expect(described_class.search(" petr ")).to contain_exactly(petrobras, recv)
    expect(described_class.search("brasileiro")).to contain_exactly(petrobras)
    expect(described_class.search("%")).to be_empty
  end
end
