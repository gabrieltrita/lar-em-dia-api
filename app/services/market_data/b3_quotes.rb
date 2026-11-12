module MarketData
  class B3Quotes
    BASE_URI = "https://bvmf.bmfbovespa.com.br/InstDados/SerHist/".freeze
    QUOTE_RECORD = "01".freeze
    CASH_MARKET = "010".freeze
    UNIT_QUOTATION_FACTOR = 1
    BDI_TYPES = { "02" => :stock, "12" => :fii }.freeze
    STOCK_SPECIFICATIONS = /\A(ON|PN[A-H]?|UNT)\b/

    Quote = Data.define(:ticker, :isin, :name, :asset_type, :quoted_on, :close_cents, :volume_cents, :trades_count)

    def self.fetch(date)
      name = "COTAHIST_D#{date.strftime('%d%m%Y')}"
      entries = Download.zip_entries(URI.join(BASE_URI, "#{name}.ZIP"), [ "#{name}.TXT" ])
      entries && parse(entries.values.first)
    end

    def self.parse(content)
      content.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8).each_line.filter_map { |line| quote(line) }
    end

    def self.quote(line)
      asset_type = BDI_TYPES[line[10, 2]]
      return unless asset_type && line[0, 2] == QUOTE_RECORD && line[24, 3] == CASH_MARKET
      return unless line[210, 7].to_i == UNIT_QUOTATION_FACTOR
      return if asset_type == :stock && !line[39, 10].match?(STOCK_SPECIFICATIONS)

      Quote.new(
        ticker: line[12, 12].strip,
        isin: line[230, 12],
        name: line[27, 12].strip,
        asset_type: asset_type,
        quoted_on: Date.strptime(line[2, 8], "%Y%m%d"),
        close_cents: line[108, 13].to_i,
        volume_cents: line[170, 18].to_i,
        trades_count: line[147, 5].to_i
      )
    end

    private_class_method :parse, :quote
  end
end
