class NoteBlueprint < Blueprinter::Base
  identifier :id

  fields :title, :body, :created_at, :updated_at
end
