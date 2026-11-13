require "rails_helper"
require "rake"

RSpec.describe "market_data tasks" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "market_data:backfill" }
  end

  before { allow(MarketDataSyncJob).to receive(:perform_now) }

  it "imports the previous weekday by default" do
    Rake::Task["market_data:sync"].execute(Rake::TaskArguments.new([ :date, :registry ], []))

    expect(MarketDataSyncJob).to have_received(:perform_now).with(nil, with_registry: false)
  end

  it "imports a given day and the CVM registry when asked" do
    Rake::Task["market_data:sync"].execute(Rake::TaskArguments.new([ :date, :registry ], [ "2026-11-11", "true" ]))

    expect(MarketDataSyncJob).to have_received(:perform_now).with("2026-11-11", with_registry: true)
  end

  it "loads the months from January of the year to last month and prints the counts" do
    allow(MarketData::Backfill).to receive(:call).and_return(MarketData::Backfill::Result.new(months: 22, assets_created: 3, quotes_saved: 9))

    expect do
      travel_to(Date.new(2026, 11, 12)) { Rake::Task["market_data:backfill"].execute(Rake::TaskArguments.new([ :year ], [ "2025" ])) }
    end.to output("{\"months\":22,\"assets_created\":3,\"quotes_saved\":9}\n").to_stdout
    expect(MarketData::Backfill).to have_received(:call).with(from: Date.new(2025, 1, 1), to: Date.new(2026, 10, 12))
  end

  it "loads the FII monthly reports of each year from the given one, refreshes the indicators and prints the counts" do
    allow(AssetIndicators).to receive(:refresh).and_return(4)
    registry = MarketData::CvmFunds::Registry.new(funds: [], reports: [])
    allow(MarketData::CvmFunds).to receive(:fetch).and_return(registry)
    allow(MarketData::FundReportSync).to receive(:call).and_return(MarketData::FundReportSync::Result.new(fund_reports_saved: 2,
      distributions_saved: 1))

    expect do
      travel_to(Date.new(2026, 11, 12)) { Rake::Task["market_data:fund_reports"].execute(Rake::TaskArguments.new([ :year ], [ "2025" ])) }
    end.to output("#{{ years: [ 2025, 2026 ].map { |year| { fund_reports_saved: 2, distributions_saved: 1, year: year } },
      indicators_saved: 4 }.to_json}\n").to_stdout
    expect(MarketData::CvmFunds).to have_received(:fetch).with(2025)
    expect(MarketData::CvmFunds).to have_received(:fetch).with(2026)
  end

  it "loads the annual statements of the catalog's companies from the given year to last year and refreshes the indicators" do
    create(:asset, cnpj: "33000167000101")
    create(:asset, cnpj: "33000167000101")
    create(:asset, :fii, cnpj: "11728688000147")
    stub_financials
    stub_market_data(format(MarketDataHelpers::FINANCIALS_URL, 2024), status: 404)
    allow(MarketData::CvmFinancials).to receive(:fetch).and_call_original

    expect do
      travel_to(Date.new(2026, 11, 12)) { Rake::Task["market_data:financials"].execute(Rake::TaskArguments.new([ :year ], [ "2024" ])) }
    end.to output("#{{ years: [ { year: 2024, financials_saved: 0 }, { year: 2025, financials_saved: 1 } ], indicators_saved: 3 }.to_json}\n").to_stdout
    expect(MarketData::CvmFinancials).to have_received(:fetch).with(2025, [ "33000167000101" ])
  end

  it "refreshes the indicators" do
    create(:asset)

    expect { Rake::Task["market_data:indicators"].execute }.to output("{\"indicators_saved\":1}\n").to_stdout
  end
end
