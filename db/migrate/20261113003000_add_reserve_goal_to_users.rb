class AddReserveGoalToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.integer :reserve_goal_months, null: false, default: 6
      t.bigint :reserve_goal_cents
    end
  end
end
