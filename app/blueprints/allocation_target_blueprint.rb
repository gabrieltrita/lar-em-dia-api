class AllocationTargetBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :mode, :amount_cents, :percent_bps, :reserve_account_id, :position, :created_at, :updated_at
end
