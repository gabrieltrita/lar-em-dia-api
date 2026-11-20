require "rails_helper"

RSpec.describe AllocationRecorder do
  let(:user) { create(:user) }
  let(:month) { Date.new(2026, 11, 1) }

  around { |example| travel_to(Date.new(2026, 11, 20)) { example.run } }

  before do
    create(:category, :expense, key: "surplus_allocation")
    create(:category, :expense, key: "reserve_deposit")
    create(:balance, user: user, as_of: Date.new(2026, 10, 31), amount_cents: 9_400)
  end

  def record(target, **params)
    recorder = described_class.new(user)
    recorder.create(target_id: target.id, month: month, **params)
    recorder.record
  end

  it "records the planned amount as a paid expense today" do
    allocation = record(create(:allocation_target, user: user, name: "Caridade", percent_bps: 800))

    expect(allocation).to be_persisted
    expect(allocation.entry).to have_attributes(kind: "expense", amount_cents: 752, due_on: Date.new(2026, 11, 20), status: "paid",
      paid_on: Date.new(2026, 11, 20), description: "Caridade", category: Category.find_by(key: "surplus_allocation"))
  end

  it "records a chosen amount on the last day of a past month" do
    allocation = described_class.new(user)
    allocation.create(target_id: create(:allocation_target, user: user).id, month: Date.new(2026, 9, 1), amount_cents: 2_500)

    expect(allocation.record.entry).to have_attributes(amount_cents: 2_500, due_on: Date.new(2026, 9, 30))
  end

  it "deposits into the linked reserve account" do
    account = create(:reserve_account, user: user, name: "Caixinha")
    allocation = record(create(:allocation_target, :remainder, user: user, reserve_account: account))

    movement = allocation.entry.reserve_movement
    expect(movement).to have_attributes(account: account, kind: "deposit", amount_cents: 9_400, moved_on: Date.new(2026, 11, 20))
    expect(allocation.entry).to have_attributes(description: "Caixinha", category: Category.find_by(key: "reserve_deposit"))
  end

  it "refuses another user's target and nothing to allocate" do
    recorder = described_class.new(user)
    expect(recorder.create(target_id: create(:allocation_target).id, month: month)).to be(false)
    expect(recorder.record.errors.details[:target].pluck(:error)).to eq([ :blank ])

    create(:balance, user: user, as_of: Date.new(2026, 11, 1), amount_cents: 0)
    recorder = described_class.new(user)
    expect(recorder.create(target_id: create(:allocation_target, user: user).id, month: month)).to be(false)
    expect(recorder.record.errors.details[:amount_cents].pluck(:error)).to eq([ :greater_than ])
    expect(Entry.count).to eq(0)
  end

  it "undoes an allocation by deleting its expense" do
    allocation = record(create(:allocation_target, :fixed, user: user))

    expect(described_class.new(user, allocation).destroy).to be(true)
    expect(Entry.exists?(allocation.entry_id)).to be(false)
    expect(Allocation.exists?(allocation.id)).to be(false)
  end

  it "undoes a reserve allocation by deleting its deposit, unless a later withdrawal needs it" do
    account = create(:reserve_account, user: user)
    target = create(:allocation_target, :fixed, user: user, reserve_account: account)
    allocation = record(target)
    withdrawal = create(:reserve_movement, user: user, account: account, kind: :withdrawal, amount_cents: 500, moved_on: Date.new(2026, 11, 20))

    recorder = described_class.new(user, allocation)
    expect(recorder.destroy).to be(false)
    expect(recorder.error_code).to eq("insufficient_reserve")

    withdrawal.destroy!
    expect(described_class.new(user, allocation.reload).destroy).to be(true)
    expect(ReserveMovement.count).to eq(0)
    expect(Allocation.count).to eq(0)
  end
end
