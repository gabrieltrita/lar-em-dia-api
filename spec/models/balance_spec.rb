require "rails_helper"

RSpec.describe Balance do
  subject { build(:balance) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:amount_cents) }
  it { is_expected.to validate_numericality_of(:amount_cents).only_integer }
  it { is_expected.to validate_presence_of(:as_of) }
  it { is_expected.to validate_uniqueness_of(:as_of).scoped_to(:user_id) }

  it "accepts a negative amount" do
    expect(build(:balance, amount_cents: -2_500)).to be_valid
  end

  it "accepts today and rejects a future date" do
    expect(build(:balance, as_of: Date.current)).to be_valid

    balance = build(:balance, as_of: Date.current + 1)
    expect(balance).not_to be_valid
    expect(balance.errors.details[:as_of]).to include(error: :in_future)
  end

  it "lists the most recent date first" do
    user = create(:user)
    older = create(:balance, user: user, as_of: 10.days.ago.to_date)
    newer = create(:balance, user: user, as_of: 1.day.ago.to_date)

    expect(user.balances.recent).to eq([ newer, older ])
  end
end
