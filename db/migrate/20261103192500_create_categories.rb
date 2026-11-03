class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories, id: :uuid do |t|
      t.string :kind, null: false
      t.string :key, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :categories, :key, unique: true
    add_index :categories, [ :kind, :position ]
  end
end
