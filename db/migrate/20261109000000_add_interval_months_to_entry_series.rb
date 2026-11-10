class AddIntervalMonthsToEntrySeries < ActiveRecord::Migration[8.1]
  def change
    add_column :entry_series, :interval_months, :integer, null: false, default: 1
  end
end
