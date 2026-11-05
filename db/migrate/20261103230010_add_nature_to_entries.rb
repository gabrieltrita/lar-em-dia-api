class AddNatureToEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :entries, :nature, :string
  end
end
