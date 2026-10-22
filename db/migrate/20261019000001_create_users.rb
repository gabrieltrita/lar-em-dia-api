class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :users, id: :uuid do |t|
      # Campos pessoais: armazenados criptografados (ver User#encrypts).
      # Usamos text porque o ciphertext é maior que o valor original.
      t.text :email, null: false
      t.text :first_name, null: false
      t.text :last_name
      t.text :phone

      t.string :password_digest, null: false
      t.integer :role, null: false, default: 0

      t.datetime :last_sign_in_at
      t.integer :sign_in_count, null: false, default: 0
      t.datetime :password_changed_at

      t.timestamps
    end

    # E-mail usa criptografia determinística, então o índice único funciona.
    add_index :users, :email, unique: true
    add_index :users, :role
  end
end
