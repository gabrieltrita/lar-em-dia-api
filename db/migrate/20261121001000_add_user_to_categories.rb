class AddUserToCategories < ActiveRecord::Migration[8.1]
  class MigrationCategory < ActiveRecord::Base
    self.table_name = "categories"
    encrypts :name
  end

  def up
    add_reference :categories, :user, foreign_key: true, type: :uuid
    change_column :categories, :name, :text
    rewrite_names { |type, name| type.serialize(name) }
  end

  def down
    rewrite_names { |type, name| type.deserialize(name) }
    change_column :categories, :name, :string
    remove_reference :categories, :user
  end

  private

  def rewrite_names
    type = MigrationCategory.type_for_attribute(:name)
    select_rows("SELECT id, name FROM categories").each do |id, name|
      execute("UPDATE categories SET name = #{quote(yield(type, name))} WHERE id = #{quote(id)}")
    end
  end
end
