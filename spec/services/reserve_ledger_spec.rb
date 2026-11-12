require "rails_helper"

RSpec.describe ReserveLedger do
  let(:user) { create(:user) }
  let(:account) { create(:reserve_account, user: user) }
  let(:daily) { BigDecimal("1.00050788") }

  before { daily_rates(:selic, (Date.new(2026, 1, 1)..Date.new(2026, 11, 11)).select(&:on_weekday?), 50_788) }

  def move(kind, moved_on, amount_cents, target = account)
    create(:reserve_movement, user: user, account: target, kind: kind, moved_on: moved_on, amount_cents: amount_cents)
  end

  def ledger
    travel_to(Date.new(2026, 11, 12)) { described_class.for_user(user).first }
  end

  it "grows each deposit and estimates the income tax of each lot by its age" do
    move(:deposit, Date.new(2026, 3, 2), 1_000_000)
    move(:deposit, Date.new(2026, 10, 1), 500_000)

    value = ledger.value_on(Date.new(2026, 11, 12))
    old_gain = 1_000_000 * daily**ReserveGrowth.weekdays(Date.new(2026, 3, 2), Date.new(2026, 11, 11)) - 1_000_000
    new_gain = 500_000 * daily**ReserveGrowth.weekdays(Date.new(2026, 10, 1), Date.new(2026, 11, 11)) - 500_000

    expect(value).to have_attributes(invested_cents: 1_500_000, gross_cents: (1_500_000 + old_gain + new_gain).round)
    expect(value.tax_cents).to eq((old_gain * BigDecimal("0.2") + new_gain * BigDecimal("0.225")).round)
    expect(value.to_h).to include(net_cents: value.gross_cents - value.tax_cents, yield_cents: value.gross_cents - 1_500_000)
  end

  it "takes withdrawals from the oldest lots first" do
    move(:deposit, Date.new(2026, 10, 1), 100_000)
    move(:deposit, Date.new(2026, 10, 2), 100_000)
    move(:withdrawal, Date.new(2026, 10, 5), 150_000)

    value = ledger.value_on(Date.new(2026, 10, 5))
    left = 100_000 * (1 - (150_000 - 100_000 * daily**2) / (100_000 * daily))

    expect(value.gross_cents).to eq((100_000 * daily**2 + 100_000 * daily - 150_000).round)
    expect(value.invested_cents).to eq(left.round)
  end

  it "restarts from an anchor, as one lot dated on it" do
    move(:deposit, Date.new(2026, 1, 5), 100_000)
    move(:anchor, Date.new(2026, 10, 1), 300_000)

    expect(ledger.value_on(Date.new(2026, 9, 30)).invested_cents).to eq(100_000)
    expect(ledger.value_on(Date.new(2026, 10, 1))).to have_attributes(gross_cents: 300_000, invested_cents: 300_000, tax_cents: 0)
  end

  it "does not tax exempt accounts or lots without gains" do
    exempt = create(:reserve_account, user: user, kind: :cdb, cdi_percent_bps: 9_000, tax_exempt: true)
    move(:deposit, Date.new(2026, 10, 1), 100_000, exempt)
    move(:anchor, Date.new(2026, 11, 12), 100_000)

    values = travel_to(Date.new(2026, 11, 12)) { described_class.for_user(user).map { |item| item.value_on(Date.new(2026, 11, 12)) } }

    expect(values.map(&:tax_cents)).to eq([ 0, 0 ])
  end

  it "flags a withdrawal larger than the account" do
    deposit = move(:deposit, Date.new(2026, 10, 1), 100_000)
    withdrawal = ReserveMovement.new(account: account, kind: :withdrawal, moved_on: Date.new(2026, 10, 1), amount_cents: 100_001)

    expect(described_class.for(account, [ deposit, withdrawal ]).shortfall?).to be(true)
    expect(described_class.for(account, [ deposit ]).shortfall?).to be(false)
    expect(described_class.for(account, []).value_on(Date.new(2026, 10, 1))).to eq(ReserveLedger::Value.empty)
  end

  it "empties the account when everything is withdrawn" do
    move(:deposit, Date.new(2026, 10, 1), 100_000)
    move(:withdrawal, Date.new(2026, 10, 1), 100_000)

    expect(ledger.value_on(Date.new(2026, 11, 1))).to eq(ReserveLedger::Value.empty)
  end

  it "answers no accounts for a user without a reserve" do
    expect(described_class.for_user(create(:user))).to eq([])
  end
end
