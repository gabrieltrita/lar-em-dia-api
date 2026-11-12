class CreateInvestmentTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :investment_transactions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.references :position, null: false, foreign_key: { to_table: :investment_positions }, type: :uuid, index: false
      t.references :entry, foreign_key: { on_delete: :nullify }, type: :uuid, index: { unique: true }
      t.string :kind, null: false
      t.date :traded_on, null: false
      t.bigint :quantity, null: false
      t.bigint :price_cents
      t.bigint :fees_cents, null: false, default: 0

      t.timestamps
    end

    add_index :investment_transactions, %i[position_id traded_on]
    add_index :investment_transactions, %i[user_id traded_on]
  end
end
