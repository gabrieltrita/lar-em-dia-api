require "rails_helper"

RSpec.describe MarketData::CvmFundPortfolios do
  let(:property_header) do
    "CNPJ_Fundo_Classe;Data_Referencia;Versao;Classe;Nome_Imovel;Area;Percentual_Vacancia;Percentual_Inadimplencia;Percentual_Receitas_FII"
  end
  let(:tenant_header) { "CNPJ_Fundo_Classe;Data_Referencia;Versao;Nome_Imovel;Setor_Atuacao;Percentual_Receita_Imovel;Percentual_Receitas_FII" }

  def stub_rows(properties, tenants)
    stub_market_data(format(MarketDataHelpers::PORTFOLIOS_URL, 2025), status: 404)
    stub_request(:get, format(MarketDataHelpers::PORTFOLIOS_URL, 2026)).to_return(body: zip_of(
      "inf_trimestral_fii_imovel_2026.csv" => [ property_header, *properties ].join("\r\n").encode(Encoding::ISO_8859_1),
      "inf_trimestral_fii_imovel_renda_acabado_inquilino_2026.csv" => [ tenant_header, *tenants ].join("\r\n").encode(Encoding::ISO_8859_1)
    ))
  end

  it "reads each fund's properties and largest tenant from its latest quarterly report" do
    stub_fund_portfolios

    portfolios = described_class.fetch(2026).index_by(&:cnpj)

    expect(portfolios.keys).to contain_exactly("11728688000147", "97521225000125", "08417532000130")
    hglg = portfolios["11728688000147"]
    expect(hglg).to have_attributes(reference_on: Date.new(2026, 9, 30), largest_tenant_bps: 466)
    expect(hglg.properties.size).to eq(36)
    expect(hglg.properties.first).to have_attributes(name: "HGLG Betim Business Park", kind: "rent", area_m2: 35_331, vacancy_bps: 0,
      delinquency_bps: 0, revenue_share_bps: 141)
    expect(portfolios["97521225000125"].properties).to all(have_attributes(kind: "sale", vacancy_bps: nil, revenue_share_bps: nil))
    expect(portfolios["97521225000125"].largest_tenant_bps).to be_nil
  end

  it "maps every property class, keeps the latest version and skips unusable rows and values" do
    stub_rows(
      [
        "11.111.111/0001-11;2026-09-30;2;Imóveis para renda em construção;Tower;0;1.5;-0.1;0.6",
        "11.111.111/0001-11;2026-09-30;2;Imóveis para venda em construção;Homes;;;;",
        "11.111.111/0001-11;2026-09-30;2;Imóveis para venda acabados;Shops;12.4;x;;",
        "11.111.111/0001-11;2026-09-30;2;Terrenos;Land;100;0;0;0",
        "11.111.111/0001-11;2026-09-30;2;Imóveis para renda acabados;;100;0;0;0",
        "11.111.111/0001-11;2026-09-30;1;Imóveis para renda acabados;Old;100;0;0;0.1",
        "22.222.222/0001-22;2026-06-30;1;Terrenos;Land;100;0;0;0",
        "33.333.333/0001-33;bad;1;Imóveis para renda acabados;Mall;100;0;0;1",
        ";2026-09-30;1;Imóveis para renda acabados;Mall;100;0;0;1"
      ],
      [
        "11.111.111/0001-11;2026-09-30;2;Tower;Varejo;0.5;0.25",
        "11.111.111/0001-11;2026-09-30;2;Tower;Varejo;0.5;0.3",
        "11.111.111/0001-11;2026-09-30;1;Old;Varejo;1;0.9"
      ]
    )

    portfolio = described_class.fetch(2026).sole

    expect(portfolio).to have_attributes(cnpj: "11111111000111", reference_on: Date.new(2026, 9, 30), largest_tenant_bps: 3_000)
    expect(portfolio.properties.map(&:to_h)).to eq([
      { name: "Tower", kind: "rent_construction", area_m2: nil, vacancy_bps: nil, delinquency_bps: nil, revenue_share_bps: 6_000 },
      { name: "Homes", kind: "sale_construction", area_m2: nil, vacancy_bps: nil, delinquency_bps: nil, revenue_share_bps: nil },
      { name: "Shops", kind: "sale", area_m2: 12, vacancy_bps: nil, delinquency_bps: nil, revenue_share_bps: nil }
    ])
  end
end
