class CreateInterestRates < ActiveRecord::Migration[8.1]
  def change
    create_table :interest_rates, id: :uuid do |t|
      t.string :series, null: false
      t.date :rate_on, null: false
      t.bigint :rate_e8, null: false

      t.timestamps
    end

    add_index :interest_rates, %i[series rate_on], unique: true
  end
end
