class FundCompositionBlueprint < Blueprinter::Base
  fields :reference_on, :largest_tenant_bps
  field(:properties) do |composition|
    sorted = composition.properties.sort_by { |property| [ -property.revenue_share_bps.to_i, property.name ] }
    FundPropertyBlueprint.render_as_hash(sorted)
  end
end
