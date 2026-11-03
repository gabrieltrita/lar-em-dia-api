class CategoryBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :key, :name, :position, :default_nature
end
