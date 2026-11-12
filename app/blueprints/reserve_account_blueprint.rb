class ReserveAccountBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :kind, :cdi_percent_bps, :annual_rate_bps, :tax_exempt, :created_at, :updated_at
end
