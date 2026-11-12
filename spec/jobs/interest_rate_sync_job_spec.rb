require "rails_helper"

RSpec.describe InterestRateSyncJob do
  before do
    allow(Rails.logger).to receive(:info)
    allow(InterestRates::Sync).to receive(:call).and_return("selic" => 10, "cdi" => 10, "savings" => 15, "selic_target" => 15)
  end

  it "imports the last 15 days of rates" do
    travel_to(Time.zone.local(2026, 11, 12, 8)) { described_class.perform_now }

    expect(InterestRates::Sync).to have_received(:call).with(from: Date.new(2026, 10, 28), to: Date.new(2026, 11, 12))
    expect(Rails.logger).to have_received(:info).with(
      { job: "InterestRateSyncJob", date: "2026-11-12", status: "synced", "selic" => 10, "cdi" => 10, "savings" => 15, "selic_target" => 15 }
    )
  end

  it "imports up to a given day" do
    described_class.perform_now("2026-11-01")

    expect(InterestRates::Sync).to have_received(:call).with(from: Date.new(2026, 10, 17), to: Date.new(2026, 11, 1))
  end

  it "retries later when the Central Bank is unavailable" do
    allow(InterestRates::Sync).to receive(:call).and_raise(MarketData::Unavailable)

    expect { described_class.perform_now("2026-11-11") }.to have_enqueued_job(described_class).with("2026-11-11")
  end

  it "is scheduled in sidekiq-cron" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))

    expect(schedule["interest_rate_sync"]).to include("class" => "InterestRateSyncJob", "cron" => "0 8 * * 2-6 America/Sao_Paulo")
  end
end
