class InterestRateSyncJob < ApplicationJob
  WINDOW = 15

  queue_as :default

  retry_on MarketData::Unavailable, wait: 1.hour, attempts: 3

  def perform(date = nil)
    to = date ? Date.iso8601(date) : Date.current
    counts = InterestRates::Sync.call(from: to - WINDOW, to: to)
    Rails.logger.info({ job: self.class.name, date: to.iso8601, status: "synced", **counts })
  end
end
