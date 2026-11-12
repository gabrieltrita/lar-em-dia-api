class ReserveMovementBlueprint < Blueprinter::Base
  identifier :id

  fields :account_id, :kind, :moved_on, :amount_cents, :entry_id, :created_at, :updated_at
end
