class CreateAssetDistributions < ActiveRecord::Migration[8.1]
  def change
    create_table :asset_distributions, id: :uuid do |t|
      t.references :asset, null: false, foreign_key: true, type: :uuid, index: false
      t.references :user, foreign_key: true, type: :uuid, index: false
      t.string :kind, null: false
      t.string :source, null: false
      t.date :record_on, null: false
      t.date :paid_on
      t.bigint :amount_per_share_e8, null: false

      t.timestamps
    end

    add_index :asset_distributions, %i[asset_id kind record_on], unique: true, where: "source = 'cvm'",
      name: "index_asset_distributions_on_cvm_record"
    add_index :asset_distributions, %i[asset_id record_on]
    add_index :asset_distributions, %i[user_id record_on]
  end
end
