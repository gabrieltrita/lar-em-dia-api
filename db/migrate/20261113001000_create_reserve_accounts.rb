class CreateReserveAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :reserve_accounts, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.text :name, null: false
      t.string :kind, null: false
      t.integer :cdi_percent_bps
      t.integer :annual_rate_bps
      t.boolean :tax_exempt, null: false, default: false

      t.timestamps
    end
  end
end
