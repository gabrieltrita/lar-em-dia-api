class CreateAllocationTargets < ActiveRecord::Migration[8.1]
  def change
    create_table :allocation_targets, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.references :reserve_account, foreign_key: { on_delete: :nullify }, type: :uuid
      t.text :name, null: false
      t.string :mode, null: false
      t.bigint :amount_cents
      t.integer :percent_bps
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :allocation_targets, %i[user_id position]
    add_index :allocation_targets, :user_id, unique: true, where: "mode = 'remainder'", name: "index_allocation_targets_on_user_remainder"
  end
end
