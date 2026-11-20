require "rails_helper"

RSpec.describe MarketData::CvmFunds do
  def stub_rows(general, complement, holdings = [ holdings_header ])
    stub_market_data(format(MarketDataHelpers::FUNDS_URL, 2025), status: 404)
    stub_request(:get, format(MarketDataHelpers::FUNDS_URL, 2026)).to_return(body: zip_of(
      "inf_mensal_fii_geral_2026.csv" => general.join("\r\n").encode(Encoding::ISO_8859_1),
      "inf_mensal_fii_complemento_2026.csv" => complement.join("\r\n").encode(Encoding::ISO_8859_1),
      "inf_mensal_fii_ativo_passivo_2026.csv" => holdings.join("\r\n").encode(Encoding::ISO_8859_1)
    ))
  end

  let(:general_rows) { [ "CNPJ_Fundo_Classe;Data_Referencia;Versao;Nome_Fundo_Classe;Codigo_ISIN;Segmento_Atuacao" ] }
  let(:holdings_header) { "CNPJ_Fundo_Classe;Data_Referencia;Versao;Direitos_Bens_Imoveis;Imoveis_Venda_Construcao;CRI_CRA;LCI;FII" }

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

  it "classifies each month by its holdings: brick, paper, fund of funds or hybrid, with the share under development" do
    stub_cvm_registry

    reports = described_class.fetch(2026).reports.index_by { |report| [ report.cnpj, report.reference_month ] }

    expect(reports[[ "11728688000147", Date.new(2026, 9, 1) ]]).to have_attributes(category: "brick", development_bps: 0)
    expect(reports[[ "97521225000125", Date.new(2026, 9, 1) ]]).to have_attributes(category: "paper", development_bps: 556)
    expect(reports[[ "08417532000130", Date.new(2026, 1, 1) ]]).to have_attributes(category: "brick")
  end

  it "reads fund of funds, hybrid and empty holdings from the latest version of the month" do
    complement = %w[1 2 3 4].map { |digit| "#{digit * 2}.#{digit * 3}.#{digit * 3}/0001-#{digit * 2};2026-09-01;1;10;1000;10;100;0.01" }
    stub_rows(general_rows, [ complement_header, *complement ], [
      holdings_header,
      "11.111.111/0001-11;2026-09-01;1;0;0;0;0;900",
      "11.111.111/0001-11;2026-09-01;2;100;0;0;0;900",
      "22.222.222/0001-22;2026-09-01;1;400;300;200;100;300",
      "33.333.333/0001-33;2026-09-01;1;0;0;0;0;0"
    ])

    reports = described_class.fetch(2026).reports.index_by(&:cnpj)

    expect(reports["11111111000111"]).to have_attributes(category: "fund_of_funds", development_bps: 0)
    expect(reports["22222222000122"]).to have_attributes(category: "hybrid", development_bps: 3_000)
    expect(reports["33333333000133"]).to have_attributes(category: nil, development_bps: nil)
    expect(reports["44444444000144"]).to have_attributes(category: nil, development_bps: nil)
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
