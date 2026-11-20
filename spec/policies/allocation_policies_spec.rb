require "rails_helper"

RSpec.describe "Allocation policies" do
  let(:user) { create(:user) }
  let(:allocation) { create(:allocation, user: user) }
  let(:other) { create(:allocation) }

  it "lets users list and create destinations and touch only their own" do
    policy = AllocationTargetPolicy

    expect(policy.new(user, AllocationTarget).index?).to be(true)
    expect(policy.new(user, AllocationTarget.new).create?).to be(true)
    expect(%i[update? destroy?].map { |action| policy.new(user, allocation.target).public_send(action) }).to all(be(true))
    expect(%i[update? destroy?].map { |action| policy.new(user, other.target).public_send(action) }).to all(be(false))
    expect(policy::Scope.new(user, AllocationTarget).resolve).to contain_exactly(allocation.target)
  end

  it "lets users use destinations and undo only their own allocations" do
    expect(AllocationPolicy.new(user, Allocation.new).create?).to be(true)
    expect(AllocationPolicy.new(user, allocation).destroy?).to be(true)
    expect(AllocationPolicy.new(user, other).destroy?).to be(false)
    expect(AllocationPolicy::Scope.new(user, Allocation).resolve).to contain_exactly(allocation)
  end

  it "lets any user see their plan" do
    expect(AllocationPlanPolicy.new(user, :allocation_plan).show?).to be(true)
  end
end
