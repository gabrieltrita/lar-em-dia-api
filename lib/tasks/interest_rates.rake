namespace :interest_rates do
  desc "Load the Selic, CDI, savings and Selic target series from the Central Bank, from January of YEAR to today (idempotent)"
  task :backfill, [ :year ] => :environment do |_task, args|
    today = Date.current
    counts = (Integer(args.fetch(:year))..today.year).map do |year|
      InterestRates::Sync.call(from: Date.new(year, 1, 1), to: [ Date.new(year, 12, 31), today ].min)
    end
    puts counts.reduce { |total, year| total.merge(year) { |_series, a, b| a + b } }.to_json
  end

  desc "Import the last 15 days of interest rates now (default: up to today)"
  task :sync, [ :date ] => :environment do |_task, args|
    InterestRateSyncJob.perform_now(args[:date].presence)
  end
end
