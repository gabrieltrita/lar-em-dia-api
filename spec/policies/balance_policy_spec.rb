require "rails_helper"

RSpec.describe BalancePolicy do
  let(:owner) { create(:user) }
  let(:balance) { create(:balance, user: owner) }

  it "lets the owner do everything" do
    policy = described_class.new(owner, balance)
    expect([ policy.index?, policy.create?, policy.show?, policy.update?, policy.destroy? ]).to all(be(true))
  end

  it "keeps other users and admins away" do
    [ create(:user), create(:user, :admin) ].each do |other|
      policy = described_class.new(other, balance)
      expect([ policy.show?, policy.update?, policy.destroy? ]).to all(be(false))
    end
  end

  it "scopes the list to the user's own records" do
    balance
    create(:balance)
    expect(described_class::Scope.new(owner, Balance).resolve).to contain_exactly(balance)
  end
end
