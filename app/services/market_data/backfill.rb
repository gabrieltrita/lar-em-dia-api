module MarketData
  class Backfill
    Result = Data.define(:months, :assets_created, :quotes_saved)

    def self.call(from:, to:)
      new(from, to).call
    end

    def initialize(from, to)
      @months = (from.beginning_of_month..to.beginning_of_month).select { |day| day.day == 1 }
    end

    def call
      totals = @months.map { |month| save(B3Quotes.month_end(month)) }
      Result.new(months: @months.size, assets_created: totals.sum(&:first), quotes_saved: totals.sum(&:last))
    end

    private

    def save(quotes)
      return [ 0, 0 ] if quotes.blank?

      now = Time.current
      created = Asset.insert_all(quotes.map { |quote| asset_row(quote, now) }, unique_by: :ticker, returning: :id).length
      ids = Asset.where(ticker: quotes.map(&:ticker)).pluck(:ticker, :id).to_h
      saved = AssetQuote.insert_all(quotes.map { |quote| quote_row(quote, ids.fetch(quote.ticker), now) }, unique_by: %i[asset_id quoted_on],
        returning: :id).length
      [ created, saved ]
    end

    def asset_row(quote, now)
      { ticker: quote.ticker, isin: quote.isin, name: quote.name, asset_type: quote.asset_type.to_s, active: false, created_at: now,
        updated_at: now }
    end

    def quote_row(quote, asset_id, now)
      { asset_id: asset_id, quoted_on: quote.quoted_on, close_cents: quote.close_cents, volume_cents: quote.volume_cents,
        trades_count: quote.trades_count, created_at: now, updated_at: now }
    end
  end
end
