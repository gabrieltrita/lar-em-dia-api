require "rails_helper"

RSpec.describe MarketData::CvmFunds do
  it "reads ISIN, CNPJ, name and segment from the FII monthly reports of the year and the one before" do
    stub_cvm_registry

    funds = described_class.fetch(2026).index_by(&:isin)

    expect(funds.keys).to contain_exactly("BRHGLGCTF004", "BRMXRFCTF008", "BRXPMLCTF000")
    expect(funds["BRMXRFCTF008"]).to have_attributes(cnpj: "97521225000125", name: "FII MAXI RENDA RL", sector: "Logística")
    expect(funds["BRXPMLCTF000"]).to have_attributes(name: "XP MALLS FII", sector: "Shoppings")
  end

  it "keeps the latest report of each fund" do
    rows = [
      "CNPJ_Fundo_Classe;Data_Referencia;Versao;Nome_Fundo_Classe;Codigo_ISIN;Segmento_Atuacao",
      "11.728.688/0001-47;2026-09-01;1;NEW NAME;BRHGLGCTF004;",
      "11.728.688/0001-47;2026-08-01;2;OLD NAME;BRHGLGCTF004;Logística"
    ]
    stub_market_data(format(MarketDataHelpers::FUNDS_URL, 2025), status: 404)
    stub_request(:get, format(MarketDataHelpers::FUNDS_URL, 2026))
      .to_return(body: zip_of("inf_mensal_fii_geral_2026.csv" => rows.join("\r\n").encode(Encoding::ISO_8859_1)))

    expect(described_class.fetch(2026)).to contain_exactly(
      have_attributes(isin: "BRHGLGCTF004", cnpj: "11728688000147", name: "NEW NAME", sector: nil)
    )
  end
end
