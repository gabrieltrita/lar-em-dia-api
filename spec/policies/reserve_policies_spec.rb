require "rails_helper"

RSpec.describe "Reserve policies" do
  let(:user) { create(:user) }
  let(:movement) { create(:reserve_movement, user: user) }
  let(:other) { create(:reserve_movement) }

  it "lets users list and create movements and touch only their own" do
    policy = ReserveMovementPolicy

    expect(policy.new(user, ReserveMovement).index?).to be(true)
    expect(policy.new(user, ReserveMovement.new).create?).to be(true)
    expect(%i[show? update? destroy?].map { |action| policy.new(user, movement).public_send(action) }).to all(be(true))
    expect(%i[show? update? destroy?].map { |action| policy.new(user, other).public_send(action) }).to all(be(false))
    expect(policy::Scope.new(user, ReserveMovement).resolve).to contain_exactly(movement)
  end

  it "lets users list and create accounts and touch only their own" do
    policy = ReserveAccountPolicy

    expect(policy.new(user, ReserveAccount).index?).to be(true)
    expect(policy.new(user, ReserveAccount.new).create?).to be(true)
    expect(%i[show? update? destroy?].map { |action| policy.new(user, movement.account).public_send(action) }).to all(be(true))
    expect(%i[show? update? destroy?].map { |action| policy.new(user, other.account).public_send(action) }).to all(be(false))
    expect(policy::Scope.new(user, ReserveAccount).resolve).to contain_exactly(movement.account)
  end

  it "lets any user see and change their reserve" do
    expect(ReservePolicy.new(user, :reserve)).to have_attributes(show?: true, update?: true, projection?: true)
  end
end
