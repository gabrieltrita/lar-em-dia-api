require "rails_helper"

RSpec.describe InterestRates::Sync do
  it "stores the four series and updates rates that changed" do
    create(:interest_rate, rate_on: Date.new(2026, 10, 1), rate_e8: 1)

    expect(load_interest_rates).to eq("selic" => 28, "cdi" => 28, "savings" => 39, "selic_target" => 43)
    expect(InterestRate.count).to eq(138)
    expect(InterestRate.selic.find_by!(rate_on: Date.new(2026, 10, 1)).rate_e8).to eq(50_788)
  end

  it "counts zero for a series without rates in the period" do
    stub_request(:get, /api\.bcb\.gov\.br/).to_return(status: 404)

    expect(described_class.call(from: Date.new(2026, 11, 14), to: Date.new(2026, 11, 15)).values).to eq([ 0, 0, 0, 0 ])
  end
end
