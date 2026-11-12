require "rails_helper"

RSpec.describe ReserveAccount do
  def error_codes(account, attribute)
    account.validate
    account.errors.where(attribute).map(&:type)
  end

  it { is_expected.to belong_to(:user) }

  it "is valid as a Treasury Selic account and squishes the name" do
    expect(build(:reserve_account, name: "  Tesouro   Selic ")).to have_attributes(valid?: true, name: "Tesouro Selic")
  end

  it "encrypts the name" do
    account = create(:reserve_account, name: "Caixinha")

    expect(described_class.connection.select_value("SELECT name FROM reserve_accounts WHERE id = '#{account.id}'")).not_to include("Caixinha")
  end

  it "validates the name and the kind" do
    expect(error_codes(build(:reserve_account, name: ""), :name)).to eq([ :blank ])
    expect(error_codes(build(:reserve_account, name: "a" * 101), :name)).to eq([ :too_long ])
    expect(build(:reserve_account, kind: "crypto")).not_to be_valid
  end

  it "requires the CDI percentage on a CDB and the annual rate on a fixed rate account, and refuses them elsewhere" do
    expect(error_codes(build(:reserve_account, :cdb, cdi_percent_bps: nil), :cdi_percent_bps)).to eq([ :rate_required ])
    expect(error_codes(build(:reserve_account, kind: :fixed_rate), :annual_rate_bps)).to eq([ :rate_required ])
    expect(error_codes(build(:reserve_account, cdi_percent_bps: 10_000), :cdi_percent_bps)).to eq([ :rate_not_allowed ])
    expect(error_codes(build(:reserve_account, :cdb, annual_rate_bps: 1_000), :annual_rate_bps)).to eq([ :rate_not_allowed ])
    expect(error_codes(build(:reserve_account, :cdb, cdi_percent_bps: 50_001), :cdi_percent_bps)).to eq([ :less_than_or_equal_to ])
    expect(error_codes(build(:reserve_account, kind: :fixed_rate, annual_rate_bps: 0), :annual_rate_bps)).to eq([ :greater_than ])
  end

  it "is exempt when marked, and savings and idle money always are" do
    expect(%i[selic_treasury savings idle].map { |kind| build(:reserve_account, kind: kind).exempt? }).to eq([ false, true, true ])
    expect(build(:reserve_account, :cdb, tax_exempt: true).exempt?).to be(true)
  end

  it "deletes its movements and the entries they created" do
    account = create(:reserve_account)
    entry = create(:entry, user: account.user)
    create(:reserve_movement, user: account.user, account: account, entry: entry)
    create(:reserve_movement, user: account.user, account: account, moved_on: Date.new(2026, 10, 2))
    other = create(:entry, user: account.user)

    account.destroy_with_entries!

    expect(ReserveMovement.count).to eq(0)
    expect(Entry.pluck(:id)).to eq([ other.id ])
  end
end
