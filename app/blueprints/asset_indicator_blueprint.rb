class AssetIndicatorBlueprint < Blueprinter::Base
  fields :computed_on, :price_cents, :dy_12m_bps, :distribution_average_e8, :distribution_median_e8, :years_paying, :payout_bps, :p_vp_e2,
    :p_l_e2, :roe_average_bps, :earnings_cagr_bps, :equity_cagr_bps, :years_with_profit, :net_margin_bps, :net_debt_to_equity_bps,
    :liquidity_cents, :financial_years, :fund_category, :development_bps, :properties_count, :largest_property_bps, :vacancy_bps,
    :delinquency_bps, :largest_tenant_bps, :months_paying_12m
end
