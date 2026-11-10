class EntrySeriesBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :interval_months, :entries_count, :total_cents, :created_at

  association :entries, blueprint: EntryBlueprint
end
