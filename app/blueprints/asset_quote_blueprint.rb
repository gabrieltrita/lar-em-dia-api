class AssetQuoteBlueprint < Blueprinter::Base
  fields :quoted_on, :close_cents, :volume_cents, :trades_count
end
