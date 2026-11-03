class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :category, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.text :description, null: false
      t.bigint :amount_cents, null: false
      t.date :due_on, null: false
      t.string :status, null: false, default: "pending"
      t.date :paid_on

      t.timestamps
    end

    add_index :entries, [ :user_id, :due_on ]
    add_index :entries, [ :user_id, :kind, :due_on ]
  end
end
