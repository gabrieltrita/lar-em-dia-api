require "rails_helper"

RSpec.describe MarketData::CvmFunds do
  def stub_rows(general, complement)
    stub_market_data(format(MarketDataHelpers::FUNDS_URL, 2025), status: 404)
    stub_request(:get, format(MarketDataHelpers::FUNDS_URL, 2026)).to_return(body: zip_of(
      "inf_mensal_fii_geral_2026.csv" => general.join("\r\n").encode(Encoding::ISO_8859_1),
      "inf_mensal_fii_complemento_2026.csv" => complement.join("\r\n").encode(Encoding::ISO_8859_1)
    ))
  end

  let(:complement_header) do
    "CNPJ_Fundo_Classe;Data_Referencia;Versao;Total_Numero_Cotistas;Patrimonio_Liquido;Cotas_Emitidas;Valor_Patrimonial_Cotas;" \
      "Percentual_Dividend_Yield_Mes"
  end

  it "reads ISIN, CNPJ, name and segment from the FII monthly reports of the year and the one before" do
    stub_cvm_registry

    funds = described_class.fetch(2026).funds.index_by(&:isin)

    expect(funds.keys).to contain_exactly("BRHGLGCTF004", "BRMXRFCTF008", "BRXPMLCTF000")
    expect(funds["BRMXRFCTF008"]).to have_attributes(cnpj: "97521225000125", name: "FII MAXI RENDA RL", sector: "Logística")
    expect(funds["BRXPMLCTF000"]).to have_attributes(name: "XP MALLS FII", sector: "Shoppings")
  end

  it "reads equity, book value, shares, shareholders and the month's income per share from the complement" do
    stub_cvm_registry

    reports = described_class.fetch(2026).reports

    expect(reports.size).to eq(15)
    expect(reports).to include(
      have_attributes(
        cnpj: "11728688000147", reference_month: Date.new(2026, 1, 1), equity_cents: 705_651_499_900, book_value_per_share_e8: 16_640_889_239,
        shares_count: 42_404_675, shareholders_count: 536_031, income_per_share_e8: 109_896_433
      ),
      have_attributes(cnpj: "11728688000147", reference_month: Date.new(2025, 12, 1)),
      have_attributes(cnpj: "08417532000130", reference_month: Date.new(2026, 1, 1), income_per_share_e8: nil)
    )
  end

  it "keeps the latest version of each fund and month and skips incomplete rows" do
    stub_rows(
      [
        "CNPJ_Fundo_Classe;Data_Referencia;Versao;Nome_Fundo_Classe;Codigo_ISIN;Segmento_Atuacao",
        "11.728.688/0001-47;2026-09-01;1;NEW NAME;BRHGLGCTF004;",
        "11.728.688/0001-47;2026-08-01;2;OLD NAME;BRHGLGCTF004;Logística"
      ],
      [
        complement_header,
        "11.728.688/0001-47;2026-09-01;2;10;1000.5;10;100.05;0.01",
        "11.728.688/0001-47;2026-09-01;1;9;900;10;90;",
        "11.728.688/0001-47;bad;1;9;900;10;90;0.01",
        "11.728.688/0001-47;2026-08-01;1;9;0;10;90;0.01",
        ";2026-08-01;1;9;900;10;90;0.01"
      ]
    )

    registry = described_class.fetch(2026)

    expect(registry.funds).to contain_exactly(have_attributes(isin: "BRHGLGCTF004", cnpj: "11728688000147", name: "NEW NAME", sector: nil))
    expect(registry.reports).to contain_exactly(
      have_attributes(reference_month: Date.new(2026, 9, 1), equity_cents: 100_050, shareholders_count: 10, income_per_share_e8: 100_050_000)
    )
  end
end
