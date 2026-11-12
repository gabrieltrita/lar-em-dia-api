FactoryBot.define do
  factory :reserve_account do
    user
    name { "Tesouro Selic" }
    kind { :selic_treasury }

    trait :cdb do
      name { "CDB liquidez diária" }
      kind { :cdb }
      cdi_percent_bps { 10_000 }
    end
  end
end
