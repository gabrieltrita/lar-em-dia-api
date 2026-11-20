class CreateAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :allocations, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.references :target, null: false, foreign_key: { to_table: :allocation_targets, on_delete: :cascade }, type: :uuid, index: false
      t.references :entry, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.date :month, null: false

      t.timestamps
    end

    add_index :allocations, %i[target_id month], unique: true
    add_index :allocations, %i[user_id month]
  end
end
