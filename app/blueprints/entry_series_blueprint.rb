class EntrySeriesBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :entries_count, :created_at

  association :entries, blueprint: EntryBlueprint
end
