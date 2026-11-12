class CreateReserveMovements < ActiveRecord::Migration[8.1]
  def change
    create_table :reserve_movements, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.references :account, null: false, foreign_key: { to_table: :reserve_accounts, on_delete: :cascade }, type: :uuid, index: false
      t.references :entry, foreign_key: { on_delete: :nullify }, type: :uuid, index: { unique: true }
      t.string :kind, null: false
      t.date :moved_on, null: false
      t.bigint :amount_cents, null: false

      t.timestamps
    end

    add_index :reserve_movements, %i[account_id moved_on]
    add_index :reserve_movements, %i[user_id moved_on]
  end
end
