class AssetBlueprint < Blueprinter::Base
  identifier :ticker

  fields :name, :asset_type, :sector
  association :indicator, name: :indicators, blueprint: AssetIndicatorBlueprint

  view :detail do
    fields :isin, :cnpj, :active
    association :latest_quote, name: :quote, blueprint: AssetQuoteBlueprint
    association :latest_fund_report, name: :fund_report, blueprint: FundReportBlueprint
  end
end
