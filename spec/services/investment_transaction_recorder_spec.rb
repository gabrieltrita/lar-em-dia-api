require "rails_helper"

RSpec.describe InvestmentTransactionRecorder do
  let(:user) { create(:user) }
  let!(:petr) { create(:asset, ticker: "PETR4") }
  let!(:hglg) { create(:asset, :fii, ticker: "HGLG11") }
  let(:params) { { ticker: "petr4", kind: "buy", traded_on: "2026-10-01", quantity: 100, price_cents: 3_000, fees_cents: 50 } }

  before do
    create(:category, :expense, key: "investment_contribution")
    create(:category, key: "investment_redemption")
  end

  def record(attributes = {})
    recorder = described_class.new(user)
    recorder.create(params.merge(attributes))
    recorder.record
  end

  it "opens the position with the default goal of the asset type, or the one sent" do
    expect(record.position).to have_attributes(asset: petr, goal: "growth")
    expect(record(ticker: "HGLG11").position.goal).to eq("income")
    user.investment_positions.destroy_all
    expect(record(goal: "income").position.goal).to eq("income")
  end

  it "keeps the goal of an existing position" do
    record
    expect(record(goal: "income").position.reload.goal).to eq("growth")
  end

  it "rejects an unknown ticker or an invalid goal" do
    recorder = described_class.new(user)
    expect(recorder.create(params.merge(ticker: "XXXX3"))).to be(false)
    expect(recorder.record.errors.details[:ticker].pluck(:error)).to eq([ :unknown_asset ])

    expect { described_class.new(user).create(params.merge(goal: "luck")) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(InvestmentPosition.count).to eq(0)
  end

  it "creates a paid expense for a buy and a paid income for a sell with debit_balance" do
    buy = record(debit_balance: true)
    sell = record(kind: "sell", quantity: 40, price_cents: 3_500, fees_cents: 20, traded_on: "2026-10-10", debit_balance: true)

    expect(buy.entry).to have_attributes(kind: "expense", amount_cents: 300_050, due_on: Date.new(2026, 10, 1), status: "paid",
      description: "PETR4 × 100", nature: "variable")
    expect(sell.entry).to have_attributes(kind: "income", amount_cents: 139_980, paid_on: Date.new(2026, 10, 10), nature: nil)
  end

  it "updates the linked entry, keeps it without debit_balance and deletes it with false" do
    transaction = record(debit_balance: true)
    entry = transaction.entry

    expect(described_class.new(user, transaction).update(price_cents: 3_100, ticker: "PETR4", quantity: 50)).to be(true)
    expect(entry.reload).to have_attributes(amount_cents: 155_050, kind: "expense")

    record(traded_on: "2026-09-01")
    expect(described_class.new(user, transaction).update(kind: "sell")).to be(true)
    expect(entry.reload).to have_attributes(amount_cents: 154_950, kind: "income", nature: nil)

    described_class.new(user, transaction).update(debit_balance: false)
    expect(Entry.exists?(entry.id)).to be(false)
    expect(transaction.reload.entry_id).to be_nil
  end

  it "refuses a sale that the position does not cover" do
    record
    recorder = described_class.new(user)

    expect(recorder.create(params.merge(kind: "sell", quantity: 101))).to be(false)
    expect(recorder.record.errors.details[:quantity].pluck(:error)).to eq([ :insufficient_quantity ])
  end

  it "refuses to change the ticker" do
    recorder = described_class.new(user, record)

    expect(recorder.update(ticker: "HGLG11")).to be(false)
    expect(recorder.record.errors.details[:ticker].pluck(:error)).to eq([ :immutable ])
  end

  it "deletes the transaction with its entry, and the position with its last transaction" do
    first = record(debit_balance: true)
    second = record(traded_on: "2026-10-02")

    expect(described_class.new(user, first).destroy).to be(true)
    expect(Entry.exists?(first.entry_id)).to be(false)
    expect(InvestmentPosition.exists?(second.position_id)).to be(true)

    expect(described_class.new(user, second).destroy).to be(true)
    expect(InvestmentPosition.exists?(second.position_id)).to be(false)
  end

  it "refuses to delete a buy that a later sale needs" do
    buy = record
    record(kind: "sell", quantity: 100, traded_on: "2026-10-05")
    recorder = described_class.new(user, buy)

    expect(recorder.destroy).to be(false)
    expect(recorder.error_code).to eq("insufficient_quantity")
    expect(InvestmentTransaction.exists?(buy.id)).to be(true)
  end
end
