require "rails_helper"
require "rake"

RSpec.describe "interest_rates tasks" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "interest_rates:backfill" }
  end

  it "loads the rates year by year up to today and prints the counts" do
    allow(InterestRates::Sync).to receive(:call).and_return("selic" => 250, "cdi" => 250, "savings" => 336, "selic_target" => 365)

    expect do
      travel_to(Date.new(2026, 11, 12)) { Rake::Task["interest_rates:backfill"].execute(Rake::TaskArguments.new([ :year ], [ "2025" ])) }
    end.to output("{\"selic\":500,\"cdi\":500,\"savings\":672,\"selic_target\":730}\n").to_stdout
    expect(InterestRates::Sync).to have_received(:call).with(from: Date.new(2025, 1, 1), to: Date.new(2025, 12, 31))
    expect(InterestRates::Sync).to have_received(:call).with(from: Date.new(2026, 1, 1), to: Date.new(2026, 11, 12))
  end

  it "imports the latest rates now, or up to a given day" do
    allow(InterestRateSyncJob).to receive(:perform_now)

    Rake::Task["interest_rates:sync"].execute(Rake::TaskArguments.new([ :date ], []))
    Rake::Task["interest_rates:sync"].execute(Rake::TaskArguments.new([ :date ], [ "2026-11-11" ]))

    expect(InterestRateSyncJob).to have_received(:perform_now).with(nil)
    expect(InterestRateSyncJob).to have_received(:perform_now).with("2026-11-11")
  end
end
