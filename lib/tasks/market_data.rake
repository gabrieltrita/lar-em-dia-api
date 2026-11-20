namespace :market_data do
  desc "Load month-end quotes from B3's monthly COTAHIST files, from January of YEAR to last month (idempotent)"
  task :backfill, [ :year ] => :environment do |_task, args|
    result = MarketData::Backfill.call(from: Date.new(Integer(args.fetch(:year)), 1, 1), to: Date.current.prev_month)
    puts result.to_h.to_json
  end

  desc "Load the FII monthly and quarterly reports (distributions, holdings and properties) from CVM, from YEAR to this year, then refresh the indicators (idempotent)"
  task :fund_reports, [ :year ] => :environment do |_task, args|
    results = (Integer(args.fetch(:year))..Date.current.year).map do |year|
      MarketData::FundReportSync.call(MarketData::CvmFunds.fetch(year).reports).to_h
        .merge(portfolios_saved: MarketData::FundPortfolioSync.call(MarketData::CvmFundPortfolios.fetch(year)), year: year)
    end
    puts({ years: results, indicators_saved: AssetIndicators.refresh }.to_json)
  end

  desc "Load the companies' annual statements (DFP) from CVM, from YEAR to last year, then refresh the indicators (idempotent)"
  task :financials, [ :year ] => :environment do |_task, args|
    cnpjs = Asset.stock.where.not(cnpj: nil).distinct.pluck(:cnpj)
    results = (Integer(args.fetch(:year))...Date.current.year).map do |year|
      { year: year, financials_saved: MarketData::FinancialSync.call(MarketData::CvmFinancials.fetch(year, cnpjs).to_a) }
    end
    puts({ years: results, indicators_saved: AssetIndicators.refresh }.to_json)
  end

  desc "Recompute the indicators of every listed asset from the stored quotes, distributions and statements"
  task indicators: :environment do
    puts({ indicators_saved: AssetIndicators.refresh }.to_json)
  end

  desc "Import one day's B3 quotes now (default: the previous weekday); pass registry=true to refresh the CVM registry too"
  task :sync, [ :date, :registry ] => :environment do |_task, args|
    MarketDataSyncJob.perform_now(args[:date].presence, with_registry: args[:registry] == "true")
  end
end
