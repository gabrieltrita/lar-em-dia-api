FactoryBot.define do
  factory :note do
    user
    sequence(:title) { |n| "Note #{n}" }
    body { "Remember to buy milk" }
  end
end
