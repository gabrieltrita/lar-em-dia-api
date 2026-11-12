require "rails_helper"

RSpec.describe "Investment policies" do
  let(:user) { create(:user) }
  let(:transaction) { create(:investment_transaction, user: user) }
  let(:other) { create(:investment_transaction) }

  it "lets users list and create transactions and touch only their own" do
    policy = InvestmentTransactionPolicy

    expect(policy.new(user, InvestmentTransaction).index?).to be(true)
    expect(policy.new(user, InvestmentTransaction.new).create?).to be(true)
    expect(%i[show? update? destroy?].map { |action| policy.new(user, transaction).public_send(action) }).to all(be(true))
    expect(%i[show? update? destroy?].map { |action| policy.new(user, other).public_send(action) }).to all(be(false))
    expect(policy::Scope.new(user, InvestmentTransaction).resolve).to contain_exactly(transaction)
  end

  it "lets users change only their own positions" do
    policy = InvestmentPositionPolicy

    expect(policy.new(user, transaction.position).update?).to be(true)
    expect(policy.new(user, other.position).update?).to be(false)
    expect(policy::Scope.new(user, InvestmentPosition).resolve).to contain_exactly(transaction.position)
  end

  it "lets any user see their portfolio" do
    expect(PortfolioPolicy.new(user, :portfolio)).to have_attributes(show?: true, history?: true)
  end
end
