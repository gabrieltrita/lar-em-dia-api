class FundPropertyBlueprint < Blueprinter::Base
  fields :name, :kind, :area_m2, :vacancy_bps, :delinquency_bps, :revenue_share_bps
end
