require "rails_helper"

RSpec.describe InterestRate do
  it "validates the series, the date and the rate" do
    create(:interest_rate)

    expect(build(:interest_rate, series: "ipca")).not_to be_valid
    expect(build(:interest_rate)).not_to be_valid
    expect(build(:interest_rate, series: :cdi)).to be_valid
    expect(build(:interest_rate, rate_on: nil)).not_to be_valid
    expect(build(:interest_rate, rate_e8: 1.5)).not_to be_valid
  end

  it "finds the latest rate of a series and the rates in a range" do
    create(:interest_rate, rate_on: Date.new(2026, 10, 1), rate_e8: 1)
    create(:interest_rate, rate_on: Date.new(2026, 10, 2), rate_e8: 2)
    create(:interest_rate, series: :cdi, rate_on: Date.new(2026, 10, 5), rate_e8: 3)

    expect(described_class.latest(:selic)).to have_attributes(rate_e8: 2, fraction: BigDecimal("0.00000002"))
    expect(described_class.between(:selic, Date.new(2026, 10, 2)..)).to eq([ [ Date.new(2026, 10, 2), 2 ] ])
  end
end
