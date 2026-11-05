class CategoryBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :key, :name, :position, :default_nature

  view :admin do
    fields :active, :created_at, :updated_at
  end
end
