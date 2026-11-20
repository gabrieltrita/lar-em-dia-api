class CreateFundCompositions < ActiveRecord::Migration[8.1]
  def change
    create_table :fund_compositions, id: :uuid do |t|
      t.references :asset, null: false, foreign_key: true, type: :uuid, index: { unique: true }
      t.date :reference_on, null: false
      t.bigint :largest_tenant_bps
      t.timestamps
    end

    create_table :fund_properties, id: :uuid do |t|
      t.references :fund_composition, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :name, null: false
      t.string :kind, null: false
      t.bigint :area_m2
      t.bigint :vacancy_bps
      t.bigint :delinquency_bps
      t.bigint :revenue_share_bps
      t.timestamps
    end

    change_table :fund_reports, bulk: true do |t|
      t.string :category
      t.bigint :development_bps
    end

    change_table :asset_indicators, bulk: true do |t|
      t.string :fund_category
      t.bigint :development_bps
      t.integer :properties_count
      t.bigint :largest_property_bps
      t.bigint :vacancy_bps
      t.bigint :delinquency_bps
      t.bigint :largest_tenant_bps
      t.integer :months_paying_12m
    end
  end
end
