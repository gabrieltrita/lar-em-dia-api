module MarketData
  class CvmFunds
    BASE_URI = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/".freeze
    CENTS = 100
    E8 = 100_000_000
    BPS = 10_000
    PREDOMINANT = Rational(2, 3)
    BRICK = %w[Direitos_Bens_Imoveis Acoes_Sociedades_Atividades_FII Cotas_Sociedades_Atividades_FII].freeze
    PAPER = %w[CRI CRI_CRA LCI LCI_LCA LIG Letras_Hipotecarias].freeze
    FUND_OF_FUNDS = %w[FII].freeze
    DEVELOPMENT = %w[Terrenos Imoveis_Renda_Construcao Imoveis_Venda_Acabados Imoveis_Venda_Construcao].freeze

    Fund = Data.define(:isin, :cnpj, :name, :sector)
    Report = Data.define(:cnpj, :reference_month, :equity_cents, :book_value_per_share_e8, :shares_count, :shareholders_count,
      :income_per_share_e8, :category, :development_bps)
    Registry = Data.define(:funds, :reports)

    def self.fetch(year)
      files = [ year - 1, year ].map { |report_year| files(report_year) }
      compositions = latest(files.flat_map(&:last)).index_by { |row| key(row) }
      Registry.new(funds: funds(files.flat_map(&:first)), reports: reports(files.flat_map(&:second), compositions))
    end

    def self.files(year)
      names = %w[geral complemento ativo_passivo].map { |part| "inf_mensal_fii_#{part}_#{year}.csv" }
      contents = Download.zip_entries(URI.join(BASE_URI, "inf_mensal_fii_#{year}.zip"), names)
      contents ? names.map { |name| rows(contents.fetch(name)) } : [ [], [], [] ]
    end

    def self.rows(content)
      CvmCsv.parse(content).map(&:itself)
    end

    def self.funds(rows)
      latest(rows).filter_map { |row| fund(row) }.index_by(&:isin).values
    end

    def self.reports(rows, compositions)
      latest(rows).filter_map { |row| report(row, compositions[key(row)]) }.index_by { |report| [ report.cnpj, report.reference_month ] }.values
    end

    def self.key(row)
      [ row["CNPJ_Fundo_Classe"].to_s.delete("^0-9"), row["Data_Referencia"].to_s ]
    end

    def self.latest(rows)
      rows.sort_by { |row| [ row["Data_Referencia"].to_s, row["Versao"].to_i ] }
    end

    def self.fund(row)
      isin = row["Codigo_ISIN"].to_s.strip.upcase
      cnpj = row["CNPJ_Fundo_Classe"].to_s.delete("^0-9")
      name = CvmCsv.text(row["Nome_Fundo_Classe"])
      return unless name && isin.match?(Asset::ISIN_FORMAT) && cnpj.match?(Asset::CNPJ_FORMAT)

      Fund.new(isin: isin, cnpj: cnpj, name: name, sector: CvmCsv.text(row["Segmento_Atuacao"]))
    end

    def self.report(row, holdings)
      cnpj = row["CNPJ_Fundo_Classe"].to_s.delete("^0-9")
      month = month(row["Data_Referencia"])
      equity, book_value, shares = %w[Patrimonio_Liquido Valor_Patrimonial_Cotas Cotas_Emitidas].map { |column| positive(row[column]) }
      return unless cnpj.match?(Asset::CNPJ_FORMAT) && month && equity && book_value && shares

      yield_rate = positive(row["Percentual_Dividend_Yield_Mes"])
      Report.new(
        cnpj: cnpj, reference_month: month, equity_cents: (equity * CENTS).round,
        book_value_per_share_e8: (book_value * E8).round, shares_count: shares.round, shareholders_count: row["Total_Numero_Cotistas"].to_i,
        income_per_share_e8: yield_rate && (yield_rate * book_value * E8).round, **composition(holdings)
      )
    end

    def self.composition(row)
      values = row.to_h
      sums = [ BRICK, PAPER, FUND_OF_FUNDS, DEVELOPMENT ].map { |columns| columns.sum { |column| positive(values[column]) || 0 } }
      total = sums.take(3).sum
      return { category: nil, development_bps: nil } unless total.positive?

      shares = %w[brick paper fund_of_funds].zip(sums).to_h { |category, sum| [ category, sum / total ] }
      { category: shares.find { |_category, share| share >= PREDOMINANT }&.first || "hybrid", development_bps: (sums.last / total * BPS).round }
    end

    def self.month(value)
      Date.iso8601(value.to_s).beginning_of_month
    rescue Date::Error
      nil
    end

    def self.positive(value)
      number = BigDecimal(value.to_s.strip, exception: false)
      number if number&.positive?
    end

    private_class_method :files, :rows, :funds, :reports, :key, :latest, :fund, :report, :composition, :month, :positive
  end
end
