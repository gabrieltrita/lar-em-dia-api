class AddCategoryToAllocationTargets < ActiveRecord::Migration[8.1]
  def change
    add_reference :allocation_targets, :category, type: :uuid, foreign_key: true
  end
end
