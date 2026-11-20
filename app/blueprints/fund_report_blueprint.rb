class FundReportBlueprint < Blueprinter::Base
  field(:reference_month) { |report| report.reference_month.strftime("%Y-%m") }
  fields :equity_cents, :book_value_per_share_e8, :shares_count, :shareholders_count, :category, :development_bps
end
