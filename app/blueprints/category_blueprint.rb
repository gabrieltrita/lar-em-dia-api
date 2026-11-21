class CategoryBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :key, :name, :position, :default_nature

  field(:custom) { |category| category.custom? }

  view :admin do
    fields :active, :created_at, :updated_at
  end
end
