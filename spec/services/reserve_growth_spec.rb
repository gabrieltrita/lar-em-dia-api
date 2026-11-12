require "rails_helper"

RSpec.describe ReserveGrowth do
  let(:today) { Date.new(2026, 11, 12) }
  let(:growth) { described_class.new(since: Date.new(2026, 10, 1), today: today) }
  let(:selic) { build(:reserve_account) }

  def factor(account, from, to)
    growth.factor(account, from, to).round(10)
  end

  describe "with the Central Bank series" do
    before { load_interest_rates }

    it "compounds the Selic of each business day in the series, skipping holidays" do
      expect(factor(selic, Date.new(2026, 10, 1), Date.new(2026, 10, 8))).to eq((BigDecimal("1.00050788")**5).round(10))
      expect(factor(selic, Date.new(2026, 10, 9), Date.new(2026, 10, 14))).to eq((BigDecimal("1.00050788")**2).round(10))
    end

    it "uses the last known rate for business days the job has not imported yet" do
      later = described_class.new(since: Date.new(2026, 11, 10), today: Date.new(2026, 11, 17))

      expect(later.factor(selic, Date.new(2026, 11, 10), Date.new(2026, 11, 17)).round(10)).to eq((BigDecimal("1.00050788")**5).round(10))
    end

    it "projects future business days with the Selic target" do
      daily = described_class.annual_to_daily(BigDecimal("0.1375"))

      expect(factor(selic, Date.new(2026, 11, 13), Date.new(2026, 11, 20))).to eq(daily.power(5, 30).round(10))
    end

    it "applies the CDB percentage to the CDI, and to the estimated CDI in the future" do
      cdb = build(:reserve_account, :cdb, cdi_percent_bps: 11_000)
      future = described_class.annual_to_daily(BigDecimal("0.1365")) - 1

      expect(factor(cdb, Date.new(2026, 10, 1), Date.new(2026, 10, 2))).to eq(BigDecimal("1.000558668"))
      expect(factor(cdb, Date.new(2026, 11, 13), Date.new(2026, 11, 14))).to eq((1 + future * BigDecimal("1.1")).round(10))
    end

    it "grows a fixed rate account by its annual rate on business days" do
      fixed = build(:reserve_account, kind: :fixed_rate, annual_rate_bps: 1_200)
      daily = described_class.annual_to_daily(BigDecimal("0.12"))

      expect(factor(fixed, Date.new(2026, 10, 1), Date.new(2026, 10, 8))).to eq(daily.power(5, 30).round(10))
    end

    it "credits savings on each monthly anniversary, moving the 29th to the 31st to the 1st" do
      savings = build(:reserve_account, kind: :savings)

      expect(factor(savings, Date.new(2026, 10, 1), Date.new(2026, 10, 31))).to eq(1)
      expect(factor(savings, Date.new(2026, 10, 1), Date.new(2026, 11, 1))).to eq(BigDecimal("1.006624"))
      expect(factor(savings, Date.new(2026, 9, 30), Date.new(2026, 11, 1))).to eq(BigDecimal("1.006624"))
      expect(factor(savings, Date.new(2026, 11, 11), Date.new(2027, 1, 11))).to eq((BigDecimal("1.006699")**2).round(10))
    end

    it "does not grow idle money or a period that has not started" do
      expect(factor(build(:reserve_account, kind: :idle), Date.new(2026, 10, 1), today)).to eq(1)
      expect(factor(selic, today, today)).to eq(1)
    end

    it "states the assumptions of the future" do
      expect(growth.assumptions).to eq(
        selic_target_e8: 13_750_000, cdi_estimate_e8: 13_650_000, savings_monthly_e8: 669_900, rates_as_of: Date.new(2026, 11, 11),
        holidays_ignored: true, iof_ignored: true
      )
    end
  end

  describe "without rates" do
    it "does not grow money" do
      expect(factor(selic, Date.new(2026, 10, 1), Date.new(2027, 10, 1))).to eq(1)
      expect(factor(build(:reserve_account, kind: :savings), Date.new(2026, 10, 1), Date.new(2027, 10, 1))).to eq(1)
      expect(growth.assumptions).to include(selic_target_e8: nil, cdi_estimate_e8: nil, savings_monthly_e8: nil, rates_as_of: nil)
    end

    it "projects past days with the Selic target when no daily rate was ever imported" do
      create(:interest_rate, series: :selic_target, rate_e8: 13_750_000)
      daily = described_class.annual_to_daily(BigDecimal("0.1375"))

      expect(factor(selic, Date.new(2026, 10, 1), Date.new(2026, 10, 8))).to eq(daily.power(5, 30).round(10))
    end
  end

  describe ".tax_rate" do
    it "follows the regressive table" do
      expect([ 0, 180, 181, 360, 361, 720, 721 ].map { |days| described_class.tax_rate(days).to_s }).to eq(
        %w[0.225 0.225 0.2 0.2 0.175 0.175 0.15]
      )
    end
  end

  describe ".weekdays" do
    it "counts Monday to Friday in an inclusive range" do
      expect(described_class.weekdays(Date.new(2026, 11, 9), Date.new(2026, 11, 22))).to eq(10)
      expect(described_class.weekdays(Date.new(2026, 11, 14), Date.new(2026, 11, 16))).to eq(1)
      expect(described_class.weekdays(Date.new(2026, 11, 16), Date.new(2026, 11, 15))).to eq(0)
    end
  end
end
