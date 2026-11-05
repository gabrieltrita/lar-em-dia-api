require "rails_helper"

RSpec.describe EntrySeries do
  subject(:series) { build(:entry_series, direction: "forward") }

  it { is_expected.to be_valid }
  it { is_expected.to validate_numericality_of(:entries_count).only_integer.is_greater_than_or_equal_to(2).is_less_than_or_equal_to(36) }
  it { is_expected.to validate_inclusion_of(:direction).in_array(%w[forward backward]).on(:create) }

  it { is_expected.to validate_absence_of(:total_cents) }

  it "keeps a saved series with a single entry left" do
    series.save!
    series.entries_count = 1
    expect(series).to be_valid
    series.entries_count = 0
    expect(series).not_to be_valid
  end

  context "with installments" do
    subject(:series) { build(:entry_series, kind: :installments, entries_count: 3, total_cents: 10_000) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_numericality_of(:entries_count).only_integer.is_less_than_or_equal_to(48) }

    it "needs at least one cent per installment" do
      series.total_cents = 2
      expect(series).not_to be_valid
      expect(series.errors.details[:total_cents]).to eq([ { error: :greater_than_or_equal_to, value: 2, count: 3 } ])
    end

    it "requires the total" do
      series.total_cents = nil
      series.validate
      expect(series.errors.details[:total_cents].pluck(:error)).to include(:not_a_number)
    end

    it "splits the total and gives the leftover cents to the first installment" do
      expect(series.installment_amounts).to eq([ 3_334, 3_333, 3_333 ])
    end
  end

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
