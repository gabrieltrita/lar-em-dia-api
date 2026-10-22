FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    phone { "+5511999990000" }
    password { "Senha@123" }
    role { :user }
    confirmed_at { Time.current }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :with_2fa do
      otp_secret { ROTP::Base32.random }
      otp_enabled_at { Time.current }
    end

    trait :admin do
      role { :admin }
      with_2fa
    end

    trait :admin_without_2fa do
      role { :admin }
    end
  end
end
