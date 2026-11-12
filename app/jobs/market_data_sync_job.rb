class MarketDataSyncJob < ApplicationJob
  queue_as :default

  retry_on MarketData::Unavailable, wait: 1.hour, attempts: 3

  def perform(date = nil, with_registry: false)
    date = date ? Date.iso8601(date) : Date.current.prev_weekday
    quotes = MarketData::B3Quotes.fetch(date)
    return log(date, status: "no_file") if quotes.nil?

    registry = with_registry || date.monday? ? registry(date.year) : {}
    log(date, status: "synced", **MarketData::CatalogSync.call(quotes, **registry).to_h)
  end

  private

  def registry(year)
    { funds: MarketData::CvmFunds.fetch(year), companies: MarketData::CvmCompanies.fetch(year) }
  end

  def log(date, **fields)
    Rails.logger.info({ job: self.class.name, date: date.iso8601, **fields })
  end
end
