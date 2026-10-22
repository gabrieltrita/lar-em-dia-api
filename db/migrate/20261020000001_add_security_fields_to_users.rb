class AddSecurityFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.datetime :confirmed_at
      t.text :unconfirmed_email

      t.integer :failed_login_attempts, null: false, default: 0
      t.datetime :locked_until

      t.text :otp_secret
      t.datetime :otp_enabled_at
      t.bigint :otp_last_used_step
      t.string :otp_backup_code_digests, array: true, null: false, default: []

      t.datetime :anonymized_at
    end

    add_index :users, :confirmed_at
    add_index :users, :anonymized_at
  end
end
