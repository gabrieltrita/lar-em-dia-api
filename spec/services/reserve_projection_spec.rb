require "rails_helper"

RSpec.describe ReserveProjection do
  let(:user) { create(:user) }
  let(:today) { Date.new(2026, 11, 12) }

  before { load_interest_rates }

  it "projects each account and the total month by month" do
    account = create(:reserve_account, user: user)
    create(:reserve_movement, user: user, account: account, kind: :deposit, moved_on: Date.new(2026, 10, 1), amount_cents: 1_000_000)

    months = travel_to(today) { described_class.new(user, months: 2).months }

    expect(months.pluck(:month)).to eq(%w[2026-11 2026-12])
    expect(months.first).to include(gross_cents: 1_020_557, net_cents: 1_015_932, accounts: [ { id: account.id, gross_cents: 1_020_557, net_cents: 1_015_932 } ])
    expect(months.last[:net_cents]).to be > months.first[:net_cents]
  end

  it "answers the net total on a date and the assumptions" do
    projection = travel_to(today) { described_class.new(user) }

    expect(projection.net_cents_on(today)).to eq(0)
    expect(projection.assumptions).to include(selic_target_e8: 13_750_000, rates_as_of: Date.new(2026, 11, 11))
  end
end
