class AllocationBlueprint < Blueprinter::Base
  identifier :id

  fields :target_id, :entry_id, :created_at, :updated_at

  field(:month) { |allocation| allocation.month.strftime("%Y-%m") }
  field(:amount_cents) { |allocation| allocation.entry.amount_cents }
  field(:used_on) { |allocation| allocation.entry.due_on }
end
