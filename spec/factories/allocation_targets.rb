FactoryBot.define do
  factory :allocation_target do
    user
    name { "Renda fixa" }
    mode { :percent }
    percent_bps { 1_000 }

    trait :fixed do
      mode { :fixed }
      percent_bps { nil }
      amount_cents { 1_000 }
    end

    trait :remainder do
      name { "Reserva" }
      mode { :remainder }
      percent_bps { nil }
    end
  end
end
