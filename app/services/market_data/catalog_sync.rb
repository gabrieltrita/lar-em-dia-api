module MarketData
  class CatalogSync
    Result = Data.define(:quotes_received, :quotes_saved, :deactivated, :funds_matched, :companies_matched)

    def self.call(quotes, funds: [], companies: [])
      new(quotes, funds, companies).call
    end

    def initialize(quotes, funds, companies)
      @quotes = quotes.select(&:catalogable?)
      @received = quotes.size
      @funds = funds
      @companies = companies
      @now = Time.current
    end

    def call
      Asset.transaction do
        save_quotes
        Result.new(
          quotes_received: @received,
          quotes_saved: @quotes.size,
          deactivated: deactivate,
          funds_matched: enrich(Asset.fii.where(isin: @funds.map(&:isin)), @funds.index_by(&:isin), :isin),
          companies_matched: enrich(Asset.stock.where(ticker: @companies.map(&:ticker)), @companies.index_by(&:ticker), :ticker)
        )
      end
    end

    private

    def save_quotes
      return if @quotes.empty?

      Asset.upsert_all(@quotes.map { |quote| asset_row(quote) }, unique_by: :ticker, update_only: %i[isin asset_type active])
      ids = Asset.where(ticker: @quotes.map(&:ticker)).pluck(:ticker, :id).to_h
      AssetQuote.upsert_all(@quotes.map { |quote| quote_row(quote, ids.fetch(quote.ticker)) }, unique_by: %i[asset_id quoted_on],
        update_only: %i[close_cents volume_cents trades_count])
    end

    def deactivate
      return 0 if @quotes.empty?

      recent = AssetQuote.where(quoted_on: (@quotes.map(&:quoted_on).max - Asset::INACTIVE_AFTER)..).select(:asset_id)
      Asset.listed.where.not(id: recent).update_all(active: false, updated_at: @now)
    end

    def enrich(assets, records, key)
      assets.to_a.each do |asset|
        record = records.fetch(asset.public_send(key))
        asset.update_columns(cnpj: record.cnpj, name: record.name, sector: record.sector, updated_at: @now)
      end.size
    end

    def asset_row(quote)
      { ticker: quote.ticker, isin: quote.isin, name: quote.name, asset_type: quote.asset_type.to_s, active: true, created_at: @now,
        updated_at: @now }
    end

    def quote_row(quote, asset_id)
      { asset_id: asset_id, quoted_on: quote.quoted_on, close_cents: quote.close_cents, volume_cents: quote.volume_cents,
        trades_count: quote.trades_count, created_at: @now, updated_at: @now }
    end
  end
end
