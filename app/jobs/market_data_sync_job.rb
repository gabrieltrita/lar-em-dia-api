class MarketDataSyncJob < ApplicationJob
  queue_as :default

  retry_on MarketData::Unavailable, wait: 1.hour, attempts: 3

  def perform(date = nil, with_registry: false)
    date = date ? Date.iso8601(date) : Date.current.prev_weekday
    quotes = MarketData::B3Quotes.fetch(date)
    return log(date, status: "no_file") if quotes.nil?

    return log(date, status: "synced", **MarketData::CatalogSync.call(quotes).to_h) unless with_registry || date.monday?

    funds = MarketData::CvmFunds.fetch(date.year)
    catalog = MarketData::CatalogSync.call(quotes, funds: funds.funds, companies: MarketData::CvmCompanies.fetch(date.year))
    log(date, status: "synced", **catalog.to_h, **MarketData::FundReportSync.call(funds.reports).to_h)
  end

  private

  def log(date, **fields)
    Rails.logger.info({ job: self.class.name, date: date.iso8601, **fields })
  end
end
