class EntrySeriesBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :entries_count, :total_cents, :created_at

  association :entries, blueprint: EntryBlueprint
end
