class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.string :provider, null: false
      t.text :provider_uid, null: false
      t.text :email_at_link

      t.timestamps
    end

    add_index :identities, [ :provider, :provider_uid ], unique: true
    add_index :identities, [ :user_id, :provider ], unique: true
  end
end
