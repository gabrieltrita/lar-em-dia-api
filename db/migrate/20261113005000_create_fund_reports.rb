class CreateFundReports < ActiveRecord::Migration[8.1]
  def change
    create_table :fund_reports, id: :uuid do |t|
      t.references :asset, null: false, foreign_key: true, type: :uuid, index: false
      t.date :reference_month, null: false
      t.bigint :equity_cents, null: false
      t.bigint :book_value_per_share_e8, null: false
      t.bigint :shares_count, null: false
      t.integer :shareholders_count, null: false

      t.timestamps
    end

    add_index :fund_reports, %i[asset_id reference_month], unique: true
  end
end
