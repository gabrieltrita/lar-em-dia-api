class AssetDistributionBlueprint < Blueprinter::Base
  identifier :id

  fields :ticker, :kind, :source, :record_on, :paid_on, :amount_per_share_e8, :net_amount_per_share_e8, :created_at, :updated_at
end
