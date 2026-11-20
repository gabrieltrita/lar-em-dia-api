class MarketDataSyncJob < ApplicationJob
  queue_as :default

  retry_on MarketData::Unavailable, wait: 1.hour, attempts: 3

  def perform(date = nil, with_registry: false)
    date = date ? Date.iso8601(date) : Date.current.prev_weekday
    quotes = MarketData::B3Quotes.fetch(date)
    return log(date, status: "no_file") if quotes.nil?

    fields = with_registry || date.monday? ? registry(date, quotes) : MarketData::CatalogSync.call(quotes).to_h
    log(date, status: "synced", **fields, indicators_saved: AssetIndicators.refresh)
  end

  private

  def registry(date, quotes)
    funds = MarketData::CvmFunds.fetch(date.year)
    catalog = MarketData::CatalogSync.call(quotes, funds: funds.funds, companies: MarketData::CvmCompanies.fetch(date.year))
    financials = MarketData::CvmFinancials.fetch(date.year - 1, Asset.stock.where.not(cnpj: nil).distinct.pluck(:cnpj))
    {
      **catalog.to_h, **MarketData::FundReportSync.call(funds.reports).to_h,
      portfolios_saved: MarketData::FundPortfolioSync.call(MarketData::CvmFundPortfolios.fetch(date.year)),
      financials_saved: MarketData::FinancialSync.call(financials.to_a)
    }
  end

  def log(date, **fields)
    Rails.logger.info({ job: self.class.name, date: date.iso8601, **fields })
  end
end
