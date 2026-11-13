require "rails_helper"

RSpec.describe AssetIndicators do
  let(:today) { Date.new(2026, 11, 11) }

  def refresh = described_class.refresh(today: today)

  def financial(cnpj, year, **attributes)
    create(:company_financial, cnpj: cnpj, fiscal_year: year, revenue_cents: 4_000_000, net_income_cents: 1_000_000, equity_cents: 4_000_000,
      net_debt_cents: 2_000_000, dividends_paid_cents: 500_000, shares_count: 1_000, **attributes)
  end

  describe "for FIIs" do
    let(:fund) { create(:asset, :fii) }

    before do
      create(:asset_quote, asset: fund, quoted_on: today - 40, close_cents: 15_000, volume_cents: 999)
      create(:asset_quote, asset: fund, quoted_on: today - 1, close_cents: 16_000, volume_cents: 201)
      create(:asset_quote, asset: fund, quoted_on: today - 2, close_cents: 15_900, volume_cents: 100)
      { "2026-01-31" => 100, "2026-04-30" => 110, "2026-07-31" => 120, "2026-10-31" => 130, "2025-10-31" => 90, "2024-06-30" => 80,
        "2021-12-31" => 70 }.each do |record_on, amount|
        create(:asset_distribution, asset: fund, record_on: Date.iso8601(record_on), amount_per_share_e8: amount * 1_000_000)
      end
      create(:fund_report, asset: fund, reference_month: Date.new(2026, 8, 1), book_value_per_share_e8: 1)
      create(:fund_report, asset: fund, reference_month: Date.new(2026, 9, 1), book_value_per_share_e8: 16_547_663_017)
    end

    it "computes the income indicators from the CVM distributions of the last 12 months and the latest report" do
      expect(refresh).to eq(1)

      expect(fund.reload.indicator).to have_attributes(
        computed_on: today, price_cents: 16_000, liquidity_cents: 151, dy_12m_bps: 288, distribution_average_e8: 115_000_000,
        distribution_median_e8: 115_000_000, years_paying: 3, p_vp_e2: 97, p_l_e2: nil, roe_average_bps: nil, financial_years: nil
      )
    end

    it "takes the middle distribution of an odd count and leaves out what needs a price or a report" do
      other = create(:asset, :fii)
      create(:asset_distribution, asset: other, record_on: Date.new(2026, 10, 31), amount_per_share_e8: 50_000_000)

      refresh

      expect(other.reload.indicator).to have_attributes(price_cents: nil, liquidity_cents: nil, dy_12m_bps: nil, distribution_median_e8: 50_000_000,
        years_paying: 1, p_vp_e2: nil)
    end

    it "leaves the income indicators empty without distributions" do
      other = create(:asset, :fii)

      refresh

      expect(other.reload.indicator).to have_attributes(dy_12m_bps: nil, distribution_average_e8: nil, distribution_median_e8: nil,
        years_paying: 0)
    end
  end

  describe "for stocks" do
    let(:cnpj) { "33000167000101" }
    let!(:common) { create(:asset, ticker: "PETR3", cnpj: cnpj) }
    let!(:preferred) { create(:asset, ticker: "PETR4", cnpj: cnpj) }

    before do
      create(:asset_quote, asset: preferred, quoted_on: today - 1, close_cents: 5_000)
      financial(cnpj, 2019, net_income_cents: 1)
      financial(cnpj, 2020, net_income_cents: 100_000, equity_cents: 1_250_000, dividends_paid_cents: 10)
      financial(cnpj, 2021, net_income_cents: 200_000, equity_cents: 2_000_000)
      financial(cnpj, 2022, net_income_cents: -50_000, equity_cents: 0, dividends_paid_cents: 0)
      financial(cnpj, 2023, net_income_cents: 400_000)
      financial(cnpj, 2024, net_income_cents: 800_000)
      financial(cnpj, 2025)
    end

    it "computes the value, income and growth indicators from the company's annual statements" do
      refresh

      expect(preferred.reload.indicator).to have_attributes(
        price_cents: 5_000, dy_12m_bps: 1_000, payout_bps: 5_000, years_paying: 3, p_vp_e2: 125, p_l_e2: 500, roe_average_bps: 1_625,
        earnings_cagr_bps: 5_849, equity_cagr_bps: 2_619, years_with_profit: 4, net_margin_bps: 2_500, net_debt_to_equity_bps: 5_000,
        financial_years: 5, distribution_average_e8: nil
      )
    end

    it "shares the company's statements between its classes and leaves out what needs a price" do
      refresh

      expect(common.reload.indicator).to have_attributes(price_cents: nil, dy_12m_bps: nil, p_vp_e2: nil, p_l_e2: nil, payout_bps: 5_000,
        earnings_cagr_bps: 5_849)
    end

    it "reads share counts reported in thousands" do
      CompanyFinancial.where(cnpj: cnpj, fiscal_year: 2025).update_all(shares_count: 1)

      refresh

      expect(preferred.reload.indicator).to have_attributes(p_vp_e2: 125, p_l_e2: 500)
    end

    it "leaves out the ratios over a non-positive base and the growth of a loss" do
      CompanyFinancial.where(cnpj: cnpj, fiscal_year: 2025).update_all(net_income_cents: -1, equity_cents: -1, revenue_cents: 0, shares_count: nil)
      CompanyFinancial.where(cnpj: cnpj).where.not(fiscal_year: 2025).update_all(equity_cents: 0)

      refresh

      expect(preferred.reload.indicator).to have_attributes(dy_12m_bps: nil, payout_bps: nil, p_vp_e2: nil, p_l_e2: nil, net_margin_bps: nil,
        net_debt_to_equity_bps: nil, roe_average_bps: nil, earnings_cagr_bps: nil, equity_cagr_bps: nil, years_with_profit: 3)
    end

    it "needs two years between the statements to compute growth" do
      CompanyFinancial.where(fiscal_year: ...2024).delete_all

      refresh

      expect(preferred.reload.indicator).to have_attributes(earnings_cagr_bps: nil, equity_cagr_bps: nil, financial_years: 2)
    end

    it "leaves every statement indicator empty for a company without statements" do
      other = create(:asset, cnpj: "09346601000125")

      refresh

      expect(other.reload.indicator).to have_attributes(dy_12m_bps: nil, years_paying: nil, years_with_profit: nil, financial_years: nil)
    end
  end

  it "replaces the previous indicators and drops those of delisted assets" do
    asset = create(:asset)
    delisted = create(:asset_indicator, asset: create(:asset, :inactive))
    create(:asset_indicator, asset: asset, computed_on: today - 7, price_cents: 1)

    expect(refresh).to eq(1)

    expect(AssetIndicator.where(id: delisted.id)).to be_empty
    expect(asset.reload.indicator).to have_attributes(computed_on: today, price_cents: nil)
  end

  it "saves nothing without listed assets" do
    expect(refresh).to eq(0)
  end
end
