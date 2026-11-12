class InvestmentPositionBlueprint < Blueprinter::Base
  field(:ticker) { |position, _| position.ticker }
  fields :goal, :created_at, :updated_at
end
