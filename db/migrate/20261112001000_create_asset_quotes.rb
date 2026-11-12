class CreateAssetQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :asset_quotes, id: :uuid do |t|
      t.references :asset, null: false, foreign_key: true, type: :uuid, index: false
      t.date :quoted_on, null: false
      t.bigint :close_cents, null: false
      t.bigint :volume_cents, null: false
      t.integer :trades_count, null: false

      t.timestamps
    end

    add_index :asset_quotes, %i[asset_id quoted_on], unique: true
    add_index :asset_quotes, :quoted_on
  end
end
