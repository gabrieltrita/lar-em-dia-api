namespace :market_data do
  desc "Load month-end quotes from B3's monthly COTAHIST files, from January of YEAR to last month (idempotent)"
  task :backfill, [ :year ] => :environment do |_task, args|
    result = MarketData::Backfill.call(from: Date.new(Integer(args.fetch(:year)), 1, 1), to: Date.current.prev_month)
    puts result.to_h.to_json
  end

  desc "Load the FII monthly reports and distributions from CVM, from YEAR to this year (idempotent)"
  task :fund_reports, [ :year ] => :environment do |_task, args|
    results = (Integer(args.fetch(:year))..Date.current.year).map do |year|
      MarketData::FundReportSync.call(MarketData::CvmFunds.fetch(year).reports).to_h.merge(year: year)
    end
    puts results.to_json
  end

  desc "Import one day's B3 quotes now (default: the previous weekday); pass registry=true to refresh the CVM registry too"
  task :sync, [ :date, :registry ] => :environment do |_task, args|
    MarketDataSyncJob.perform_now(args[:date].presence, with_registry: args[:registry] == "true")
  end
end
