class AddDueAlertsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.boolean :due_alerts_enabled, null: false, default: true
      t.integer :due_alert_days_before, null: false, default: 1
      t.date :due_alerts_sent_on
    end
  end
end
