class CreateCompanyFinancials < ActiveRecord::Migration[8.1]
  def change
    create_table :company_financials, id: :uuid do |t|
      t.string :cnpj, null: false
      t.integer :fiscal_year, null: false
      t.bigint :revenue_cents, null: false
      t.bigint :net_income_cents, null: false
      t.bigint :equity_cents, null: false
      t.bigint :net_debt_cents
      t.bigint :dividends_paid_cents
      t.bigint :shares_count

      t.timestamps
    end

    add_index :company_financials, %i[cnpj fiscal_year], unique: true
  end
end
