class BalanceBlueprint < Blueprinter::Base
  identifier :id

  fields :amount_cents, :as_of, :created_at, :updated_at
end
