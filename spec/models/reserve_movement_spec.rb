require "rails_helper"

RSpec.describe ReserveMovement do
  def error_codes(movement, attribute)
    movement.validate
    movement.errors.where(attribute).map { |error| error.options[:message].is_a?(Symbol) ? error.options[:message] : error.type }
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:entry).optional }

  it "is valid as a deposit" do
    expect(build(:reserve_movement)).to be_valid
  end

  it "validates the amount, the date and the kind" do
    expect(error_codes(build(:reserve_movement, amount_cents: 0), :amount_cents)).to eq([ :greater_than ])
    expect(error_codes(build(:reserve_movement, kind: :anchor, amount_cents: 0), :amount_cents)).to eq([])
    expect(error_codes(build(:reserve_movement, kind: :anchor, amount_cents: -1), :amount_cents)).to eq([ :greater_than_or_equal_to ])
    expect(error_codes(build(:reserve_movement, amount_cents: 1.5), :amount_cents)).to eq([ :not_an_integer ])
    expect(error_codes(build(:reserve_movement, moved_on: nil), :moved_on)).to eq([ :blank ])
    expect(error_codes(build(:reserve_movement, moved_on: Date.tomorrow), :moved_on)).to eq([ :in_future ])
    expect(build(:reserve_movement, kind: "transfer")).not_to be_valid
  end

  it "refuses debit_balance on an anchor" do
    expect(error_codes(build(:reserve_movement, kind: :anchor, debit_balance: true), :debit_balance)).to eq([ :anchor_not_allowed ])
  end

  it "refuses a withdrawal larger than the account holds on its date" do
    deposit = create(:reserve_movement)
    withdrawal = build(:reserve_movement, user: deposit.user, account: deposit.account, kind: :withdrawal, amount_cents: 100_001)

    expect(error_codes(withdrawal, :amount_cents)).to eq([ :insufficient_reserve ])
    expect(build(:reserve_movement, kind: :withdrawal, account: build(:reserve_account))).not_to be_valid
  end

  it "re-checks the account when a movement changes" do
    deposit = create(:reserve_movement)
    create(:reserve_movement, user: deposit.user, account: deposit.account, kind: :withdrawal, moved_on: Date.new(2026, 10, 2), amount_cents: 60_000)

    deposit.amount_cents = 50_000
    expect(error_codes(deposit, :amount_cents)).to eq([ :insufficient_reserve ])
  end

  it "skips the account check without an account" do
    expect(error_codes(build(:reserve_movement, account: nil), :account)).to eq([ :required ])
  end
end
