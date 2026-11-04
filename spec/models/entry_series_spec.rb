require "rails_helper"

RSpec.describe EntrySeries do
  subject(:series) { build(:entry_series, direction: "forward") }

  it { is_expected.to be_valid }
  it { is_expected.to validate_numericality_of(:entries_count).only_integer.is_greater_than_or_equal_to(2).is_less_than_or_equal_to(36) }
  it { is_expected.to validate_inclusion_of(:direction).in_array(%w[forward backward]).on(:create) }

  it "is recurring by default" do
    expect(series).to be_recurring
  end

  it "lists its entries by position and deletes them with it" do
    series.save!
    second = create(:entry, user: series.user, series: series, series_position: 2)
    first = create(:entry, user: series.user, series: series, series_position: 1)

    expect(series.entries).to eq([ first, second ])
    expect { series.destroy }.to change(Entry, :count).by(-2)
  end
end
