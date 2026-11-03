class EntryBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :category_id, :description, :amount_cents, :due_on, :status, :paid_on, :created_at, :updated_at
end
