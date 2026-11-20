module MarketData
  class FundPortfolioSync
    def self.call(portfolios)
      new(portfolios).call
    end

    def initialize(portfolios)
      @portfolios = portfolios
      @now = Time.current
    end

    def call
      assets = Asset.fii.where(cnpj: @portfolios.map(&:cnpj)).pluck(:cnpj, :id).group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
      current = FundComposition.where(asset_id: assets.values.flatten).pluck(:asset_id, :reference_on).to_h
      matched = @portfolios.flat_map { |portfolio| assets.fetch(portfolio.cnpj, []).map { |asset_id| [ portfolio, asset_id ] } }
        .reject { |portfolio, asset_id| current.fetch(asset_id, portfolio.reference_on) > portfolio.reference_on }
      FundComposition.transaction { matched.each { |portfolio, asset_id| save(portfolio, asset_id) } }
      matched.size
    end

    private

    def save(portfolio, asset_id)
      composition = FundComposition.find_or_initialize_by(asset_id: asset_id)
      composition.update!(reference_on: portfolio.reference_on, largest_tenant_bps: portfolio.largest_tenant_bps)
      composition.properties.delete_all
      FundProperty.insert_all!(portfolio.properties.map { |property| property.to_h.merge(fund_composition_id: composition.id, created_at: @now, updated_at: @now) })
    end
  end
end
