FactoryBot.define do
  factory :identity do
    user
    provider { :google }
    sequence(:provider_uid) { |n| "google-uid-#{n}" }
    sequence(:email_at_link) { |n| "linked#{n}@example.com" }
  end
end
