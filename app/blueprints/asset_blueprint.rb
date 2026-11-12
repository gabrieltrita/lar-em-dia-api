class AssetBlueprint < Blueprinter::Base
  identifier :ticker

  fields :name, :asset_type, :sector

  view :detail do
    fields :isin, :cnpj, :active
    association :latest_quote, name: :quote, blueprint: AssetQuoteBlueprint
  end
end
