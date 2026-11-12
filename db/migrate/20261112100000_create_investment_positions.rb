class CreateInvestmentPositions < ActiveRecord::Migration[8.1]
  def change
    create_table :investment_positions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid, index: false
      t.references :asset, null: false, foreign_key: true, type: :uuid
      t.string :goal, null: false

      t.timestamps
    end

    add_index :investment_positions, %i[user_id asset_id], unique: true
  end
end
