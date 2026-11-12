require "rails_helper"

RSpec.describe InvestmentTransaction do
  def error_codes(transaction, attribute)
    transaction.validate
    transaction.errors.where(attribute).map { |error| error.options[:message].is_a?(Symbol) ? error.options[:message] : error.type }
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:entry).optional }

  it "is valid as a buy" do
    expect(build(:investment_transaction)).to be_valid
  end

  it "validates the quantity" do
    expect(error_codes(build(:investment_transaction, quantity: 0), :quantity)).to eq([ :greater_than ])
    expect(error_codes(build(:investment_transaction, quantity: 1.5), :quantity)).to eq([ :not_an_integer ])
    expect(error_codes(build(:investment_transaction, quantity: 1_000_000_001), :quantity)).to eq([ :less_than_or_equal_to ])
  end

  it "requires a price on trades and refuses price, fees and debit_balance otherwise" do
    expect(error_codes(build(:investment_transaction, price_cents: nil), :price_cents)).to eq([ :not_a_number ])
    split = build(:investment_transaction, :split, price_cents: 100, fees_cents: 10, debit_balance: true)

    expect(error_codes(split, :price_cents)).to eq([ :only_for_trades ])
    expect(error_codes(split, :fees_cents)).to eq([ :only_for_trades ])
    expect(error_codes(split, :debit_balance)).to eq([ :only_for_trades ])
  end

  it "rejects an unknown kind, a missing or future date and negative fees" do
    expect(build(:investment_transaction, kind: "short")).not_to be_valid
    expect(error_codes(build(:investment_transaction, traded_on: nil), :traded_on)).to eq([ :blank ])
    expect(error_codes(build(:investment_transaction, traded_on: Date.tomorrow), :traded_on)).to eq([ :in_future ])
    expect(error_codes(build(:investment_transaction, fees_cents: -1), :fees_cents)).to eq([ :greater_than_or_equal_to ])
  end

  it "needs an asset of the catalog" do
    expect(error_codes(build(:investment_transaction, position: nil), :ticker)).to eq([ :unknown_asset ])
  end

  it "refuses a sale without enough shares on its date, counting the saved transactions" do
    buy = create(:investment_transaction, traded_on: Date.new(2026, 10, 5))
    early = build(:investment_transaction, user: buy.user, position: buy.position, kind: :sell, traded_on: Date.new(2026, 10, 1))
    late = build(:investment_transaction, user: buy.user, position: buy.position, kind: :sell, traded_on: Date.new(2026, 10, 6))

    expect(error_codes(early, :quantity)).to eq([ :insufficient_quantity ])
    expect(late).to be_valid
  end

  it "replaces its own saved values when checking the position" do
    buy = create(:investment_transaction, quantity: 100)
    create(:investment_transaction, user: buy.user, position: buy.position, kind: :sell, quantity: 100, traded_on: Date.new(2026, 10, 2))
    buy.quantity = 50

    expect(error_codes(buy, :quantity)).to eq([ :insufficient_quantity ])
  end

  it "computes the cash amount of a trade" do
    expect(build(:investment_transaction, quantity: 10, price_cents: 1_000, fees_cents: 50).amount_cents).to eq(10_050)
    expect(build(:investment_transaction, kind: :sell, quantity: 10, price_cents: 1_000, fees_cents: 50).amount_cents).to eq(9_950)
  end
end
