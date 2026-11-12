namespace :market_data do
  desc "Load month-end quotes from B3's monthly COTAHIST files, from January of YEAR to last month (idempotent)"
  task :backfill, [ :year ] => :environment do |_task, args|
    result = MarketData::Backfill.call(from: Date.new(Integer(args.fetch(:year)), 1, 1), to: Date.current.prev_month)
    puts result.to_h.to_json
  end
end
