module MarketData
  class FinancialSync
    UPDATED = %i[revenue_cents net_income_cents equity_cents net_debt_cents dividends_paid_cents shares_count].freeze

    def self.call(financials)
      return 0 if financials.empty?

      now = Time.current
      CompanyFinancial.upsert_all(financials.map { |financial| financial.to_h.merge(created_at: now, updated_at: now) },
        unique_by: %i[cnpj fiscal_year], update_only: UPDATED)
      financials.size
    end
  end
end
