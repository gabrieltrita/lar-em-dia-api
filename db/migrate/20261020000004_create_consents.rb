class CreateConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :consents, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.string :version, null: false
      t.boolean :granted, null: false
      t.text :ip_address
      t.text :user_agent

      t.datetime :created_at, null: false
    end

    add_index :consents, [ :user_id, :kind, :created_at ]
  end
end
