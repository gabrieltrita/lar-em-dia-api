class AddSecurityFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      # Confirmação de e-mail / troca de e-mail
      t.datetime :confirmed_at
      t.text :unconfirmed_email

      # Bloqueio progressivo
      t.integer :failed_login_attempts, null: false, default: 0
      t.datetime :locked_until

      # 2FA (TOTP)
      t.text :otp_secret
      t.datetime :otp_enabled_at
      t.bigint :otp_last_used_step
      t.string :otp_backup_code_digests, array: true, null: false, default: []

      # LGPD: conta anonimizada em vez de apagada
      t.datetime :anonymized_at
    end

    add_index :users, :confirmed_at
    add_index :users, :anonymized_at
  end
end
