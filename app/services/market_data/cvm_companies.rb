module MarketData
  class CvmCompanies
    BASE_URI = "https://dados.cvm.gov.br/dados/CIA_ABERTA/DOC/FCA/DADOS/".freeze
    STOCK_MARKET = "Bolsa".freeze

    Company = Data.define(:ticker, :cnpj, :name, :sector)

    def self.fetch(year)
      securities = {}
      profiles = {}
      [ year - 1, year ].each do |report_year|
        entries = entries(report_year)
        next unless entries

        latest_first(entries.fetch(security_entry(report_year))).each { |row| add_security(securities, row) }
        latest_first(entries.fetch(profile_entry(report_year))).each { |row| add_profile(profiles, row) }
      end
      securities.filter_map { |ticker, cnpj| company(ticker, cnpj, profiles[cnpj]) }
    end

    def self.entries(year)
      Download.zip_entries(URI.join(BASE_URI, "fca_cia_aberta_#{year}.zip"), [ security_entry(year), profile_entry(year) ])
    end

    def self.security_entry(year) = "fca_cia_aberta_valor_mobiliario_#{year}.csv"
    def self.profile_entry(year) = "fca_cia_aberta_geral_#{year}.csv"

    def self.latest_first(content)
      CvmCsv.parse(content).sort_by { |row| [ row["Data_Referencia"].to_s, row["Versao"].to_i ] }
    end

    def self.add_security(securities, row)
      ticker = row["Codigo_Negociacao"].to_s.strip.upcase
      return unless row["Mercado"] == STOCK_MARKET && ticker.match?(Asset::TICKER_FORMAT)

      securities[ticker] = row["CNPJ_Companhia"].to_s.delete("^0-9")
    end

    def self.add_profile(profiles, row)
      profiles[row["CNPJ_Companhia"].to_s.delete("^0-9")] = row
    end

    def self.company(ticker, cnpj, profile)
      name = CvmCsv.text(profile&.fetch("Nome_Empresarial"))
      return unless name && cnpj.match?(Asset::CNPJ_FORMAT)

      Company.new(ticker: ticker, cnpj: cnpj, name: name, sector: CvmCsv.text(profile["Setor_Atividade"]))
    end

    private_class_method :entries, :security_entry, :profile_entry, :latest_first, :add_security, :add_profile, :company
  end
end
