require "rails_helper"

RSpec.describe MarketData::CvmFinancials do
  let(:url) { format(MarketDataHelpers::FINANCIALS_URL, 2025) }
  let(:cnpjs) { %w[33000167000101 09346601000125 00000000000191 00336701000104 11111111000111] }
  let(:entries) do
    Zip::File.open_buffer(StringIO.new(market_data_file("dfp_cia_aberta_2025.zip"))).entries.to_h { |entry| [ entry.name, entry.get_input_stream.read ] }
  end

  def fetch_with(changes)
    changed = entries.merge(changes.to_h { |name, change| [ name, change.call(entries.fetch(name)) ] })
    stub_request(:get, url).to_return(body: zip_of(changed))
    described_class.fetch(2025, cnpjs).index_by(&:cnpj)
  end

  def petrobras_lines(content)
    content.lines.select { |line| line.start_with?("33.000.167/0001-01") }
  end

  it "reads the consolidated statements of the requested companies from the annual DFP" do
    stub_financials

    financials = described_class.fetch(2025, cnpjs).index_by(&:cnpj)

    expect(financials.keys).to contain_exactly("33000167000101", "09346601000125", "00000000000191", "00336701000104")
    expect(financials.fetch("33000167000101")).to have_attributes(
      fiscal_year: 2025, revenue_cents: 49_754_900_000_000, net_income_cents: 11_060_500_000_000, equity_cents: 41_758_700_000_000,
      net_debt_cents: 33_341_700_000_000, dividends_paid_cents: 4_520_500_000_000, shares_count: 12_888_732_761
    )
    expect(financials.fetch("09346601000125")).to have_attributes(net_debt_cents: -59_647_300_000, dividends_paid_cents: 144_474_500_000)
  end

  it "leaves out the net debt of banks, whose balance sheets have no loans" do
    stub_financials

    bank = described_class.fetch(2025, cnpjs).find { |financial| financial.cnpj == "00000000000191" }

    expect(bank).to have_attributes(net_income_cents: 1_678_193_800_000, equity_cents: 19_356_741_600_000, net_debt_cents: nil,
      dividends_paid_cents: 668_088_900_000)
  end

  it "uses the individual statements of companies without consolidated ones" do
    stub_financials

    company = described_class.fetch(2025, cnpjs).find { |financial| financial.cnpj == "00336701000104" }

    expect(company).to have_attributes(revenue_cents: 49_100_900_000, net_income_cents: 14_050_400_000, dividends_paid_cents: 0,
      shares_count: 101_983_210)
  end

  it "returns nil when the year has no file yet" do
    stub_request(:get, url).to_return(status: 404)

    expect(described_class.fetch(2025, cnpjs)).to be_nil
  end

  it "keeps only the latest version of each statement and of the share count" do
    financials = fetch_with(
      "dfp_cia_aberta_DRE_con_2025.csv" => lambda { |content|
        content + petrobras_lines(content).map { |line| line.sub(";2025-12-31;1;", ";2025-12-31;2;").sub("110605000.0000000000", "1.0000000000") }.join
      },
      "dfp_cia_aberta_BPP_con_2025.csv" => lambda { |content|
        content + petrobras_lines(content).map { |line| line.sub(";2025-12-31;1;", ";2025-12-31;0;").sub("417587000.0000000000", "1.0000000000") }.join
      },
      "dfp_cia_aberta_composicao_capital_2025.csv" => lambda { |content|
        content + petrobras_lines(content).map { |line| line.sub(";2025-12-31;1;", ";2025-12-31;0;").sub("12888732761", "7") }.join
      }
    )

    expect(financials.fetch("33000167000101")).to have_attributes(net_income_cents: 100_000, equity_cents: 41_758_700_000_000,
      revenue_cents: 49_754_900_000_000, shares_count: 12_888_732_761)
  end

  it "reads amounts in units, skips unknown scales and leaves out companies without a result" do
    financials = fetch_with(
      "dfp_cia_aberta_DRE_con_2025.csv" => lambda { |content|
        content.lines.map { |line|
          line.start_with?("09.346.601/0001-25") ? line.sub(";MIL;", ";UNIDADE;") : line.sub(/\A(00\.000\.000.*);MIL;/, '\1;BILHAO;')
        }.join
      }
    )

    expect(financials.fetch("09346601000125")).to have_attributes(revenue_cents: 1_112_154_500, net_income_cents: 458_687_200)
    expect(financials).not_to have_key("00000000000191")
  end

  it "leaves the dividends and the share count out when those files have no rows for the company" do
    financials = fetch_with(
      "dfp_cia_aberta_DFC_MI_con_2025.csv" => ->(content) { content.lines.reject { |line| line.start_with?("33.000.167/0001-01") }.join },
      "dfp_cia_aberta_composicao_capital_2025.csv" => lambda { |content|
        content.lines.map { |line| line.start_with?("33.000.167/0001-01") ? line.sub(/;\d+\r?\n\z/, ";99999999999\n") : line }.join
      }
    )

    expect(financials.fetch("33000167000101")).to have_attributes(dividends_paid_cents: nil, shares_count: nil)
  end
end
