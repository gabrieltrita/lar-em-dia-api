class InvestmentTransactionBlueprint < Blueprinter::Base
  identifier :id

  fields :ticker, :kind, :traded_on, :quantity, :price_cents, :fees_cents, :entry_id, :created_at, :updated_at
end
