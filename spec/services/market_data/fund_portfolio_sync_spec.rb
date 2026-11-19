require "rails_helper"

RSpec.describe MarketData::FundPortfolioSync do
  def portfolio(reference_on: Date.new(2026, 9, 30), cnpj: "11728688000147", names: %w[Betim Cajamar])
    properties = names.map do |name|
      MarketData::CvmFundPortfolios::Property.new(name: name, kind: "rent", area_m2: 100, vacancy_bps: 0, delinquency_bps: 0, revenue_share_bps: 5_000)
    end
    MarketData::CvmFundPortfolios::Portfolio.new(cnpj: cnpj, reference_on: reference_on, largest_tenant_bps: 466, properties: properties)
  end

  let!(:fund) { create(:asset, :fii, ticker: "HGLG11", cnpj: "11728688000147") }

  it "saves the latest portfolio of the funds in the catalog, matched by CNPJ" do
    expect(described_class.call([ portfolio, portfolio(cnpj: "99999999000199") ])).to eq(1)

    expect(fund.fund_composition).to have_attributes(reference_on: Date.new(2026, 9, 30), largest_tenant_bps: 466)
    expect(fund.fund_composition.properties.pluck(:name)).to contain_exactly("Betim", "Cajamar")
  end

  it "replaces the properties with a newer quarter and never with an older one" do
    described_class.call([ portfolio ])
    described_class.call([ portfolio(reference_on: Date.new(2026, 12, 31), names: %w[Extrema]) ])

    expect(described_class.call([ portfolio(reference_on: Date.new(2026, 6, 30), names: %w[Old]) ])).to eq(0)
    expect(fund.reload.fund_composition.reference_on).to eq(Date.new(2026, 12, 31))
    expect(fund.fund_composition.properties.pluck(:name)).to eq(%w[Extrema])
    expect(FundProperty.count).to eq(1)
  end
end
