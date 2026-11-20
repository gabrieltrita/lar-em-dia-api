module MarketDataHelpers
  B3_URL = "https://bvmf.bmfbovespa.com.br/InstDados/SerHist/COTAHIST_D11112026.ZIP".freeze
  FUNDS_URL = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/inf_mensal_fii_%d.zip".freeze
  COMPANIES_URL = "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/FCA/DADOS/fca_cia_aberta_%d.zip".freeze
  FINANCIALS_URL = "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/DFP/DADOS/dfp_cia_aberta_%d.zip".freeze
  PORTFOLIOS_URL = "https://dados.cvm.gov.br/dados/FII/DOC/INF_TRIMESTRAL/DADOS/inf_trimestral_fii_%d.zip".freeze

  def market_data_file(name)
    file_fixture("market_data/#{name}").binread
  end

  def stub_market_data(url, fixture = nil, status: 200)
    stub_request(:get, url).to_return(status: status, body: fixture ? market_data_file(fixture) : "")
  end

  def stub_b3_quotes
    stub_market_data(B3_URL, "COTAHIST_D11112026.ZIP")
  end

  def stub_cvm_registry
    stub_market_data(format(FUNDS_URL, 2025), "inf_mensal_fii_2025.zip")
    stub_market_data(format(FUNDS_URL, 2026), "inf_mensal_fii_2026.zip")
    stub_market_data(format(COMPANIES_URL, 2025), status: 404)
    stub_market_data(format(COMPANIES_URL, 2026), "fca_cia_aberta_2026.zip")
    stub_financials
    stub_fund_portfolios
  end

  def stub_fund_portfolios
    stub_market_data(format(PORTFOLIOS_URL, 2025), status: 404)
    stub_market_data(format(PORTFOLIOS_URL, 2026), "inf_trimestral_fii_2026.zip")
  end

  def stub_financials
    stub_market_data(format(FINANCIALS_URL, 2025), "dfp_cia_aberta_2025.zip")
  end

  def zip_of(entries)
    buffer = Zip::OutputStream.write_buffer do |zip|
      entries.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end
    buffer.string
  end
end

RSpec.configure { |config| config.include MarketDataHelpers }
