require "rails_helper"

RSpec.describe InterestRates::Bcb do
  let(:from) { Date.new(2026, 10, 1) }
  let(:to) { Date.new(2026, 11, 12) }
  let(:url) { "https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados?formato=json&dataInicial=01/10/2026&dataFinal=12/11/2026" }

  before { allow(Rails.logger).to receive(:warn) }

  it "reads a real extract of the daily Selic as rates in hundred-millionths" do
    stub_request(:get, url).to_return(body: interest_rate_file(11))

    rows = described_class.fetch(:selic, from, to)

    expect(rows.size).to eq(28)
    expect(rows.first).to eq(rate_on: Date.new(2026, 10, 1), rate_e8: 50_788)
    expect(rows.pluck(:rate_on)).not_to include(Date.new(2026, 10, 12), Date.new(2026, 11, 2))
  end

  it "reads the Selic target and the savings yield of each anniversary" do
    stub_bcb_series

    expect(described_class.fetch(:selic_target, from, to).last).to eq(rate_on: Date.new(2026, 11, 12), rate_e8: 13_750_000)
    expect(described_class.fetch(:savings, from, to).first).to eq(rate_on: Date.new(2026, 10, 1), rate_e8: 662_400)
  end

  it "answers no rates when the Central Bank has none for the period" do
    stub_request(:get, url).to_return(status: 404)

    expect(described_class.fetch(:selic, from, to)).to eq([])
  end

  it "fails on an unexpected body and logs only the exception class" do
    stub_request(:get, url).to_return(body: '[{"data":"2026-10-01","valor":"0.05"}]')

    expect { described_class.fetch(:selic, from, to) }.to raise_error(MarketData::Unavailable)
    expect(Rails.logger).to have_received(:warn).with({ message: "Interest rate parsing failed", series: "selic", error: "Date::Error" })
  end

  it "fails when the body is not JSON" do
    stub_request(:get, url).to_return(body: "<html>maintenance</html>")

    expect { described_class.fetch(:selic, from, to) }.to raise_error(MarketData::Unavailable)
    expect(Rails.logger).to have_received(:warn).with(hash_including(host: "api.bcb.gov.br", error: "JSON::ParserError"))
  end
end
