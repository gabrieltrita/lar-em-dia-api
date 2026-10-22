class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs, id: :uuid do |t|
      t.references :actor, type: :uuid, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :action, null: false
      t.string :target_type
      t.uuid :target_id
      t.jsonb :metadata, null: false, default: {}
      t.text :ip_address
      t.text :user_agent
      t.string :request_id

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :action
    add_index :audit_logs, [ :target_type, :target_id ]
    add_index :audit_logs, :created_at
  end
end
