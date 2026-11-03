class DropNotes < ActiveRecord::Migration[8.1]
  def change
    drop_table :notes, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.text :title, null: false
      t.text :body
      t.timestamps
      t.index [ :user_id, :created_at ]
    end
  end
end
