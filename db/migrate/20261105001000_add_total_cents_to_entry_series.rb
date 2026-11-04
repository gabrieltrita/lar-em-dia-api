class AddTotalCentsToEntrySeries < ActiveRecord::Migration[8.1]
  def change
    add_column :entry_series, :total_cents, :bigint
  end
end
