class CreateEntrySeries < ActiveRecord::Migration[8.1]
  def change
    create_table :entry_series, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.integer :entries_count, null: false

      t.timestamps
    end

    add_reference :entries, :series, type: :uuid, foreign_key: { to_table: :entry_series }
    add_column :entries, :series_position, :integer
  end
end
