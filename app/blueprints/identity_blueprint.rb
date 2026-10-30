class IdentityBlueprint < Blueprinter::Base
  identifier :id

  fields :provider, :email_at_link, :created_at
end
