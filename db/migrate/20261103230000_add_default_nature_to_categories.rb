class AddDefaultNatureToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :default_nature, :string
  end
end
