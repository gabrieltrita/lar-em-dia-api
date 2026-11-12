class CreateAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :assets, id: :uuid do |t|
      t.string :ticker, null: false
      t.string :isin, null: false
      t.string :name, null: false
      t.string :asset_type, null: false
      t.string :cnpj
      t.string :sector
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :assets, :ticker, unique: true
    add_index :assets, :isin
    add_index :assets, :cnpj
    add_index :assets, %i[asset_type active]
  end
end
