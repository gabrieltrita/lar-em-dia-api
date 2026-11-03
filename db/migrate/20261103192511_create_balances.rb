class CreateBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :balances, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.bigint :amount_cents, null: false
      t.date :as_of, null: false

      t.timestamps
    end

    add_index :balances, [ :user_id, :as_of ], unique: true
  end
end
