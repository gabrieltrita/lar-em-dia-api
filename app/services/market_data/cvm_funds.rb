module MarketData
  class CvmFunds
    BASE_URI = "https://dados.cvm.gov.br/dados/FII/DOC/INF_MENSAL/DADOS/".freeze

    Fund = Data.define(:isin, :cnpj, :name, :sector)

    def self.fetch(year)
      [ year - 1, year ].each_with_object({}) do |report_year, funds|
        rows(report_year).sort_by { |row| [ row["Data_Referencia"].to_s, row["Versao"].to_i ] }.each do |row|
          fund = fund(row)
          funds[fund.isin] = fund if fund
        end
      end.values
    end

    def self.rows(year)
      entry = "inf_mensal_fii_geral_#{year}.csv"
      content = Download.zip_entries(URI.join(BASE_URI, "inf_mensal_fii_#{year}.zip"), [ entry ])&.fetch(entry)
      content ? CvmCsv.parse(content) : []
    end

    def self.fund(row)
      isin = row["Codigo_ISIN"].to_s.strip.upcase
      cnpj = row["CNPJ_Fundo_Classe"].to_s.delete("^0-9")
      name = CvmCsv.text(row["Nome_Fundo_Classe"])
      return unless name && isin.match?(Asset::ISIN_FORMAT) && cnpj.match?(Asset::CNPJ_FORMAT)

      Fund.new(isin: isin, cnpj: cnpj, name: name, sector: CvmCsv.text(row["Segmento_Atuacao"]))
    end

    private_class_method :rows, :fund
  end
end
