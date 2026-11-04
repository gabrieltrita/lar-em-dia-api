class EntryBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :nature, :category_id, :description, :amount_cents, :due_on, :status, :paid_on, :series_id, :series_position, :created_at, :updated_at

  field(:series_kind) { |entry, _| entry.series&.kind }
  field(:series_count) { |entry, _| entry.series&.entries_count }
end
