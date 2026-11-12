module InterestRates
  class Bcb
    URL = "https://api.bcb.gov.br/dados/serie/bcdata.sgs.%d/dados".freeze
    SERIES = { "selic" => 11, "cdi" => 12, "savings" => 195, "selic_target" => 432 }.freeze
    PERCENT_TO_E8 = 1_000_000
    DATE_FORMAT = "%d/%m/%Y".freeze

    def self.fetch(series, from, to)
      uri = URI(format(URL, SERIES.fetch(series.to_s)))
      uri.query = URI.encode_www_form(formato: "json", dataInicial: from.strftime(DATE_FORMAT), dataFinal: to.strftime(DATE_FORMAT))
      rows = MarketData::Download.json(uri) || []
      rows.map { |row| { rate_on: Date.strptime(row.fetch("data"), DATE_FORMAT), rate_e8: (BigDecimal(row.fetch("valor")) * PERCENT_TO_E8).round } }
    rescue ArgumentError, TypeError, KeyError, NoMethodError => e
      Rails.logger.warn({ message: "Interest rate parsing failed", series: series.to_s, error: e.class.name })
      raise MarketData::Unavailable
    end
  end
end
