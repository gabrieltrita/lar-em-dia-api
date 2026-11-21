require "rails_helper"

RSpec.describe AllocationTarget do
  let(:user) { create(:user) }

  it "encrypts and squishes the name" do
    target = create(:allocation_target, user: user, name: "  Renda   fixa ")

    expect(target.name).to eq("Renda fixa")
    expect(target.encrypted_attribute?(:name)).to be(true)
  end

  it "appends new targets after the last one unless a position is given" do
    first = create(:allocation_target, user: user)
    second = create(:allocation_target, user: user)
    placed = create(:allocation_target, user: user, position: 7)

    expect([ first, second, placed ].map(&:position)).to eq([ 1, 2, 7 ])
    expect(create(:allocation_target).position).to eq(1)
  end

  it "requires the value its mode uses and refuses the other" do
    fixed = build(:allocation_target, user: user, mode: :fixed)
    remainder = build(:allocation_target, user: user, mode: :remainder, amount_cents: 100)
    percent = build(:allocation_target, user: user, percent_bps: nil)

    expect(fixed).not_to be_valid
    expect(fixed.errors.details).to include(amount_cents: [ { error: :blank } ], percent_bps: [ { error: :present } ])
    expect(remainder).not_to be_valid
    expect(remainder.errors.details).to include(amount_cents: [ { error: :present } ], percent_bps: [ { error: :present } ])
    expect(percent).not_to be_valid
    expect(percent.errors.details).to include(percent_bps: [ { error: :blank } ])
  end

  it "limits percentages to 100%" do
    target = build(:allocation_target, user: user, percent_bps: 10_001)

    expect(target).not_to be_valid
    expect(target.errors.details[:percent_bps].pluck(:error)).to eq([ :less_than_or_equal_to ])
  end

  it "allows a single remainder per user" do
    create(:allocation_target, :remainder, user: user)

    expect(build(:allocation_target, :remainder, user: user)).not_to be_valid
    expect(build(:allocation_target, :remainder)).to be_valid
  end

  it "accepts only the user's own reserve accounts" do
    own = build(:allocation_target, user: user, reserve_account: create(:reserve_account, user: user))
    other = build(:allocation_target, user: user, reserve_account: create(:reserve_account))
    missing = build(:allocation_target, user: user, reserve_account_id: SecureRandom.uuid)

    expect(own).to be_valid
    expect(other).not_to be_valid
    expect(other.errors.details[:reserve_account_id].pluck(:error)).to eq([ :required ])
    expect(missing).not_to be_valid
  end

  it "accepts only active expense categories" do
    expense = create(:category, :expense)
    target = create(:allocation_target, user: user, category: expense)
    errors = lambda do |attributes|
      candidate = build(:allocation_target, user: user, **attributes)
      candidate.validate
      candidate.errors.details[:category_id].pluck(:error)
    end

    expect(errors.call(category: create(:category))).to eq([ :inclusion ])
    expect(errors.call(category: create(:category, :expense, :inactive))).to eq([ :inclusion ])
    expect(errors.call(category_id: SecureRandom.uuid)).to eq([ :required ])
    expense.update!(active: false)
    expect(target.reload).to be_valid
  end
end
