class CreateAssetIndicators < ActiveRecord::Migration[8.1]
  def change
    create_table :asset_indicators, id: :uuid do |t|
      t.references :asset, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.date :computed_on, null: false
      t.bigint :price_cents
      t.bigint :dy_12m_bps
      t.bigint :distribution_average_e8
      t.bigint :distribution_median_e8
      t.integer :years_paying
      t.bigint :payout_bps
      t.bigint :p_vp_e2
      t.bigint :p_l_e2
      t.bigint :roe_average_bps
      t.bigint :earnings_cagr_bps
      t.bigint :equity_cagr_bps
      t.integer :years_with_profit
      t.bigint :net_margin_bps
      t.bigint :net_debt_to_equity_bps
      t.bigint :liquidity_cents
      t.integer :financial_years

      t.timestamps
    end
  end
end
