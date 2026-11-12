require "rails_helper"

RSpec.describe CronSchedule do
  describe ".disabled_jobs" do
    it "reads comma-separated job names" do
      expect(described_class.disabled_jobs({ "DISABLED_CRON_JOBS" => " market_data_sync, due_alerts ,," })).to eq(%w[market_data_sync due_alerts])
    end

    it "disables nothing by default" do
      expect(described_class.disabled_jobs({})).to be_empty
    end
  end

  describe ".remove_disabled!" do
    before { allow(Sidekiq::Cron::Job).to receive(:destroy) }

    it "removes each disabled job from the schedule" do
      described_class.remove_disabled!({ "DISABLED_CRON_JOBS" => "market_data_sync" })

      expect(Sidekiq::Cron::Job).to have_received(:destroy).with("market_data_sync").once
    end

    it "keeps every job when nothing is disabled" do
      described_class.remove_disabled!({})

      expect(Sidekiq::Cron::Job).not_to have_received(:destroy)
    end

    it "names only jobs that exist in the schedule" do
      expect(YAML.load_file(Rails.root.join("config/schedule.yml")).keys).to include("market_data_sync")
    end
  end
end
