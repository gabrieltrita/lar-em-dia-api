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
        funds_matched: 0, companies_matched: 0, indicators_saved: 6 }
    )
  end

  it "refreshes the CVM registry when asked" do
    stub_b3_quotes
    stub_cvm_registry

    described_class.perform_now("2026-11-11", with_registry: true)

    expect(Asset.find_by!(ticker: "HGLG11")).to have_attributes(cnpj: "11728688000147", sector: "Multicategoria")
    expect(Asset.find_by!(ticker: "PETR4")).to have_attributes(name: "PETROLEO BRASILEIRO S.A. PETROBRAS", sector: "Petróleo e Gás")
  end

  it "imports the FII monthly reports and their income with the registry" do
    stub_b3_quotes
    stub_cvm_registry

    described_class.perform_now("2026-11-11", with_registry: true)

    hglg = Asset.find_by!(ticker: "HGLG11")
    expect(hglg.latest_fund_report).to have_attributes(reference_month: Date.new(2026, 9, 1), shareholders_count: 613_837)
    expect(hglg.distributions.find_by!(record_on: Date.new(2026, 1, 31))).to have_attributes(kind: "fii_income", source: "cvm",
      paid_on: nil, amount_per_share_e8: 109_896_433)
    expect(Rails.logger).to have_received(:info).with(hash_including(status: "synced", fund_reports_saved: 14, distributions_saved: 14))
  end

  it "imports last year's company statements with the registry and computes the indicators" do
    stub_b3_quotes
    stub_cvm_registry

    described_class.perform_now("2026-11-11", with_registry: true)

    petrobras = Asset.find_by!(ticker: "PETR4")
    expect(petrobras.financials.sole).to have_attributes(fiscal_year: 2025, net_income_cents: 11_060_500_000_000)
    expect(petrobras.indicator).to have_attributes(computed_on: Date.current, p_l_e2: be_positive, payout_bps: 4_087)
    expect(Rails.logger).to have_received(:info).with(hash_including(financials_saved: 3, indicators_saved: 6))
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
