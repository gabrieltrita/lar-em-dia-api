module MarketData
  class Unavailable < StandardError
    def initialize(message = "The market data source is unavailable")
      super
    end
  end
end
