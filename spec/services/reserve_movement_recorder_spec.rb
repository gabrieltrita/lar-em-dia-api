require "rails_helper"

RSpec.describe ReserveMovementRecorder do
  let(:user) { create(:user) }
  let(:account) { create(:reserve_account, user: user, name: "Caixinha") }
  let(:params) { { account_id: account.id, kind: "deposit", moved_on: "2026-10-01", amount_cents: 100_000 } }

  before do
    create(:category, :expense, key: "reserve_deposit")
    create(:category, key: "reserve_withdrawal")
  end

  def record(attributes = {})
    recorder = described_class.new(user)
    recorder.create(params.merge(attributes))
    recorder.record
  end

  it "creates a paid expense for a deposit and a paid income for a withdrawal with debit_balance" do
    deposit = record(debit_balance: true)
    withdrawal = record(kind: "withdrawal", amount_cents: 40_000, moved_on: "2026-10-01", debit_balance: true)

    expect(deposit.entry).to have_attributes(kind: "expense", amount_cents: 100_000, due_on: Date.new(2026, 10, 1), status: "paid",
      description: "Caixinha", nature: "variable", category: Category.find_by(key: "reserve_deposit"))
    expect(withdrawal.entry).to have_attributes(kind: "income", amount_cents: 40_000, paid_on: Date.new(2026, 10, 1), nature: nil)
  end

  it "refuses another user's account" do
    recorder = described_class.new(user)

    expect(recorder.create(params.merge(account_id: create(:reserve_account).id))).to be(false)
    expect(recorder.record.errors.details[:account].pluck(:error)).to eq([ :blank ])
  end

  it "updates the linked entry, keeps it without debit_balance and deletes it with false" do
    movement = record(debit_balance: true)
    recorder = described_class.new(user, movement)

    expect(recorder.update(amount_cents: 120_000)).to be(true)
    expect(movement.entry.reload.amount_cents).to eq(120_000)

    entry = movement.entry
    expect(recorder.update(account_id: account.id, debit_balance: false)).to be(true)
    expect(movement.reload.entry).to be_nil
    expect(Entry.exists?(entry.id)).to be(false)
    expect(recorder.update(debit_balance: false)).to be(true)
  end

  it "keeps the account" do
    movement = record
    recorder = described_class.new(user, movement)

    expect(recorder.update(account_id: create(:reserve_account, user: user).id)).to be(false)
    expect(movement.errors.details[:account_id].pluck(:error)).to eq([ :immutable ])
  end

  it "answers validation errors without saving" do
    recorder = described_class.new(user)

    expect(recorder.create(params.merge(kind: "anchor", debit_balance: true))).to be(false)
    expect(ReserveMovement.count).to eq(0)
  end

  it "deletes a movement and its entry unless a later withdrawal needs it" do
    deposit = record(debit_balance: true)
    record(kind: "withdrawal", amount_cents: 60_000, moved_on: "2026-10-02")

    refused = described_class.new(user, deposit)
    expect(refused.destroy).to be(false)
    expect(refused.error_code).to eq("insufficient_reserve")

    extra = record(moved_on: "2026-10-01")
    expect(described_class.new(user, deposit.reload).destroy).to be(true)
    expect(Entry.count).to eq(0)
    expect(described_class.new(user, extra).destroy).to be(false)
  end
end
