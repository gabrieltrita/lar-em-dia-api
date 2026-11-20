module MarketData
  class CvmFundPortfolios
    BASE_URI = "https://dados.cvm.gov.br/dados/FII/DOC/INF_TRIMESTRAL/DADOS/".freeze
    BPS = 10_000
    KINDS = {
      "Imóveis para renda acabados" => "rent",
      "Imóveis para renda em construção" => "rent_construction",
      "Imóveis para venda acabados" => "sale",
      "Imóveis para venda em construção" => "sale_construction"
    }.freeze

    Property = Data.define(:name, :kind, :area_m2, :vacancy_bps, :delinquency_bps, :revenue_share_bps)
    Portfolio = Data.define(:cnpj, :reference_on, :largest_tenant_bps, :properties)

    def self.fetch(year)
      files = [ year - 1, year ].map { |report_year| files(report_year) }
      tenants = files.flat_map(&:last).group_by { |row| version(row) }
      latest(files.flat_map(&:first)).filter_map { |key, rows| portfolio(key, rows, tenants.fetch(key, [])) }
    end

    def self.files(year)
      names = %w[imovel imovel_renda_acabado_inquilino].map { |part| "inf_trimestral_fii_#{part}_#{year}.csv" }
      contents = Download.zip_entries(URI.join(BASE_URI, "inf_trimestral_fii_#{year}.zip"), names)
      contents ? names.map { |name| CvmCsv.parse(contents.fetch(name)).map(&:itself) } : [ [], [] ]
    end

    def self.latest(rows)
      rows.group_by { |row| version(row) }.group_by { |(cnpj, *), _rows| cnpj }.values
        .map { |versions| versions.max_by { |(_cnpj, date, number), _rows| [ date, number ] } }
    end

    def self.version(row)
      [ row["CNPJ_Fundo_Classe"].to_s.delete("^0-9"), row["Data_Referencia"].to_s, row["Versao"].to_i ]
    end

    def self.portfolio(key, rows, tenants)
      cnpj, date, = key
      reference_on = Date.iso8601(date)
      properties = rows.filter_map { |row| property(row) }
      return unless cnpj.match?(Asset::CNPJ_FORMAT) && properties.any?

      Portfolio.new(cnpj: cnpj, reference_on: reference_on, properties: properties,
        largest_tenant_bps: tenants.filter_map { |row| share(row["Percentual_Receitas_FII"]) }.max)
    rescue Date::Error
      nil
    end

    def self.property(row)
      kind = KINDS[row["Classe"].to_s.strip]
      name = CvmCsv.text(row["Nome_Imovel"])
      return unless kind && name

      area = BigDecimal(row["Area"].to_s.strip, exception: false)
      Property.new(name: name, kind: kind, area_m2: area&.positive? ? area.round : nil, vacancy_bps: share(row["Percentual_Vacancia"]),
        delinquency_bps: share(row["Percentual_Inadimplencia"]), revenue_share_bps: share(row["Percentual_Receitas_FII"]))
    end

    def self.share(value)
      number = BigDecimal(value.to_s.strip, exception: false)
      (number * BPS).round if number && number >= 0 && number <= 1
    end

    private_class_method :files, :latest, :version, :portfolio, :property, :share
  end
end
