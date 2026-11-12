module MarketData
  class FundReportSync
    Result = Data.define(:fund_reports_saved, :distributions_saved)

    def self.call(reports)
      new(reports).call
    end

    def initialize(reports)
      @reports = reports
      @now = Time.current
    end

    def call
      assets = Asset.fii.where(cnpj: @reports.map(&:cnpj).uniq).pluck(:cnpj, :id).group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
      matched = @reports.flat_map { |report| assets.fetch(report.cnpj, []).map { |asset_id| [ report, asset_id ] } }
      FundReport.transaction do
        Result.new(fund_reports_saved: save_reports(matched), distributions_saved: save_distributions(matched))
      end
    end

    private

    def save_reports(matched)
      return 0 if matched.empty?

      FundReport.upsert_all(matched.map { |report, asset_id| report_row(report, asset_id) }, unique_by: %i[asset_id reference_month],
        update_only: %i[equity_cents book_value_per_share_e8 shares_count shareholders_count])
      matched.size
    end

    def save_distributions(matched)
      paying = matched.select { |report, _asset_id| report.income_per_share_e8 }
      return 0 if paying.empty?

      AssetDistribution.upsert_all(paying.map { |report, asset_id| distribution_row(report, asset_id) },
        unique_by: :index_asset_distributions_on_cvm_record, update_only: %i[amount_per_share_e8])
      paying.size
    end

    def report_row(report, asset_id)
      report.to_h.except(:cnpj, :income_per_share_e8).merge(asset_id: asset_id, created_at: @now, updated_at: @now)
    end

    def distribution_row(report, asset_id)
      { asset_id: asset_id, kind: "fii_income", source: "cvm", record_on: report.reference_month.end_of_month,
        amount_per_share_e8: report.income_per_share_e8, created_at: @now, updated_at: @now }
    end
  end
end
