require "rails_helper"
require "rake"

RSpec.describe "market_data:backfill" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "market_data:backfill" }
  end

  it "loads the months from January of the year to last month and prints the counts" do
    allow(MarketData::Backfill).to receive(:call).and_return(MarketData::Backfill::Result.new(months: 22, assets_created: 3, quotes_saved: 9))

    expect do
      travel_to(Date.new(2026, 11, 12)) { Rake::Task["market_data:backfill"].execute(Rake::TaskArguments.new([ :year ], [ "2025" ])) }
    end.to output("{\"months\":22,\"assets_created\":3,\"quotes_saved\":9}\n").to_stdout
    expect(MarketData::Backfill).to have_received(:call).with(from: Date.new(2025, 1, 1), to: Date.new(2026, 10, 12))
  end
end
