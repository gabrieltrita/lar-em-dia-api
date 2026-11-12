module InterestRates
  class Sync
    def self.call(from:, to:)
      Bcb::SERIES.keys.index_with { |series| store(series, Bcb.fetch(series, from, to)) }
    end

    def self.store(series, rows)
      return 0 if rows.empty?

      now = Time.current
      InterestRate.upsert_all(
        rows.map { |row| row.merge(series: series, created_at: now, updated_at: now) },
        unique_by: %i[series rate_on], update_only: %i[rate_e8]
      )
      rows.size
    end
  end
end
