module MarketData
  class B3Quotes
    BASE_URI = "https://bvmf.bmfbovespa.com.br/InstDados/SerHist/".freeze
    QUOTE_RECORD = "01".freeze
    CASH_MARKET = "010".freeze
    UNIT_QUOTATION_FACTOR = 1
    BDI_TYPES = { "02" => :stock, "12" => :fii }.freeze
    STOCK_SPECIFICATIONS = /\A(ON|PN[A-H]?|UNT)\b/

    Quote = Data.define(:ticker, :isin, :name, :asset_type, :quoted_on, :close_cents, :volume_cents, :trades_count) do
      def catalogable?
        ticker.match?(Asset::TICKER_FORMAT) && isin.match?(Asset::ISIN_FORMAT) && name.present? && close_cents.positive?
      end
    end

    def self.fetch(date)
      quotes = []
      found = each_quote("COTAHIST_D#{date.strftime('%d%m%Y')}") { |quote| quotes << quote }
      found && quotes
    end

    def self.month_end(month)
      latest = {}
      found = each_quote("COTAHIST_M#{month.strftime('%m%Y')}") do |quote|
        previous = latest[quote.ticker]
        latest[quote.ticker] = quote if quote.catalogable? && (previous.nil? || quote.quoted_on > previous.quoted_on)
      end
      found && latest.values
    end

    def self.each_quote(name)
      Download.zip_lines(URI.join(BASE_URI, "#{name}.ZIP"), "#{name}.TXT") do |line|
        quote = quote(line.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8))
        yield quote if quote
      end
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

    private_class_method :each_quote, :quote
  end
end
