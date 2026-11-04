FactoryBot.define do
  factory :entry_series, class: "EntrySeries" do
    user
    entries_count { 2 }
    direction { "forward" }
  end
end
