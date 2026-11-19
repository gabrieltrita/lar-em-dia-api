require "rails_helper"

RSpec.describe MarketData::FundReportSync do
  def report(**attributes)
    MarketData::CvmFunds::Report.new(
      cnpj: "11728688000147", reference_month: Date.new(2026, 9, 1), equity_cents: 754_601_779_739, book_value_per_share_e8: 16_547_663_017,
      shares_count: 45_601_713, shareholders_count: 613_837, income_per_share_e8: 116_691_920, category: "brick", development_bps: 0, **attributes
    )
  end

  let!(:fund) { create(:asset, :fii, ticker: "HGLG11", cnpj: "11728688000147") }

  it "saves the reports and income of the funds in the catalog, matched by CNPJ" do
    result = described_class.call([ report, report(cnpj: "99999999000199"), report(reference_month: Date.new(2026, 8, 1), income_per_share_e8: nil) ])

    expect(result.to_h).to eq(fund_reports_saved: 2, distributions_saved: 1)
    expect(fund.fund_reports.pluck(:reference_month)).to contain_exactly(Date.new(2026, 9, 1), Date.new(2026, 8, 1))
    expect(fund.distributions.sole).to have_attributes(kind: "fii_income", source: "cvm", record_on: Date.new(2026, 9, 30), paid_on: nil,
      amount_per_share_e8: 116_691_920)
  end

  it "updates a resubmitted month instead of duplicating it" do
    described_class.call([ report ])
    described_class.call([ report(shareholders_count: 614_000, income_per_share_e8: 117_000_000) ])

    expect(fund.fund_reports.sole.shareholders_count).to eq(614_000)
    expect(fund.distributions.sole.amount_per_share_e8).to eq(117_000_000)
  end

  it "saves nothing without matching funds" do
    expect(described_class.call([ report(cnpj: "99999999000199") ]).to_h).to eq(fund_reports_saved: 0, distributions_saved: 0)
  end
end
