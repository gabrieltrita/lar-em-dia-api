require "rails_helper"

RSpec.describe MarketData::CvmCompanies do
  it "maps the tickers traded on the exchange to the company CNPJ, name and sector" do
    stub_cvm_registry

    companies = described_class.fetch(2026).index_by(&:ticker)

    expect(companies.keys).to contain_exactly("PETR3", "PETR4", "B3SA3", "TAEE11")
    expect(companies["PETR4"]).to have_attributes(
      cnpj: "33000167000101", name: "PETROLEO BRASILEIRO S.A. PETROBRAS", sector: "Petróleo e Gás"
    )
    expect(companies["TAEE11"]).to have_attributes(cnpj: "07859971000130", name: "TRANSMISSORA ALIANÇA DE ENERGIA ELÉTRICA S.A.")
  end

  it "reads the filing of the year before and lets the year's filing replace it" do
    stub_cvm_registry
    stub_request(:get, format(MarketDataHelpers::COMPANIES_URL, 2025)).to_return(body: renamed_2025_filing)

    companies = described_class.fetch(2026).index_by(&:ticker)

    expect(companies["B3SA3"].name).to eq("B3 S.A. - BRASIL, BOLSA, BALCÃO")
    expect(companies["VALE3"]).to have_attributes(cnpj: "33592510000154", name: "VALE S.A.", sector: nil)
  end

  def renamed_2025_filing
    zip_of(
      "fca_cia_aberta_valor_mobiliario_2025.csv" => "CNPJ_Companhia;Data_Referencia;Versao;Codigo_Negociacao;Mercado\r\n" \
                                                    "09.346.601/0001-25;2025-01-01;1;B3SA3;Bolsa\r\n" \
                                                    "33.592.510/0001-54;2025-01-01;1;VALE3;Bolsa",
      "fca_cia_aberta_geral_2025.csv" => "CNPJ_Companhia;Data_Referencia;Versao;Nome_Empresarial;Setor_Atividade\r\n" \
                                         "09.346.601/0001-25;2025-01-01;1;BM&FBOVESPA S.A.;\r\n" \
                                         "33.592.510/0001-54;2025-01-01;1;VALE S.A.;"
    )
  end
end
