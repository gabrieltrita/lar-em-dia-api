require "rails_helper"

RSpec.describe MarketDataSyncJob do
  before { allow(Rails.logger).to receive(:info) }

  it "imports the previous trading day's quotes" do
    stub_b3_quotes

    travel_to(Time.zone.local(2026, 11, 12, 7)) { described_class.perform_now }

    expect(Asset.count).to eq(6)
    expect(Asset.where.not(cnpj: nil)).to be_empty
    expect(Rails.logger).to have_received(:info).with(
      { job: "MarketDataSyncJob", date: "2026-11-11", status: "synced", quotes_received: 6, quotes_saved: 6, deactivated: 0,
        funds_matched: 0, companies_matched: 0 }
    )
  end

  it "refreshes the CVM registry when asked" do
    stub_b3_quotes
    stub_cvm_registry

    described_class.perform_now("2026-11-11", with_registry: true)

    expect(Asset.find_by!(ticker: "HGLG11")).to have_attributes(cnpj: "11728688000147", sector: "Multicategoria")
    expect(Asset.find_by!(ticker: "PETR4")).to have_attributes(name: "PETROLEO BRASILEIRO S.A. PETROBRAS", sector: "Petróleo e Gás")
  end

  it "refreshes the CVM registry with Monday's quotes" do
    cotahist = Zip::File.open_buffer(StringIO.new(market_data_file("COTAHIST_D11112026.ZIP"))).read("COTAHIST_D11112026.TXT")
    stub_request(:get, "https://bvmf.bmfbovespa.com.br/InstDados/SerHist/COTAHIST_D09112026.ZIP")
      .to_return(body: zip_of("COTAHIST_D09112026.TXT" => cotahist))
    stub_cvm_registry

    described_class.perform_now("2026-11-09")

    expect(a_request(:get, format(MarketDataHelpers::COMPANIES_URL, 2026))).to have_been_made
    expect(Asset.find_by!(ticker: "B3SA3").cnpj).to eq("09346601000125")
  end

  it "logs when there is no file for the day" do
    stub_request(:get, "https://bvmf.bmfbovespa.com.br/InstDados/SerHist/COTAHIST_D02112026.ZIP").to_return(status: 404)

    described_class.perform_now("2026-11-02")

    expect(Rails.logger).to have_received(:info).with({ job: "MarketDataSyncJob", date: "2026-11-02", status: "no_file" })
  end

  it "retries later when a source is unavailable" do
    stub_request(:get, MarketDataHelpers::B3_URL).to_return(status: 503)
    allow(Rails.logger).to receive(:warn)

    expect { described_class.perform_now("2026-11-11") }.to have_enqueued_job(described_class).with("2026-11-11")
  end

  it "is scheduled in sidekiq-cron" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))

    expect(schedule["market_data_sync"]).to include("class" => "MarketDataSyncJob", "cron" => "0 7 * * 2-6 America/Sao_Paulo")
  end
end
