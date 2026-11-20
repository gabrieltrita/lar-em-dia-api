require "rails_helper"

RSpec.describe FundProperty do
  subject { build(:fund_property) }

  it { is_expected.to belong_to(:fund_composition) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(Asset::NAME_LIMIT) }

  it "rejects an unknown kind" do
    subject.kind = "land"

    expect(subject).not_to be_valid
  end

  it "counts properties for rent, finished or under construction, as income properties" do
    create(:fund_property, kind: :rent)
    create(:fund_property, kind: :rent_construction)
    create(:fund_property, kind: :sale)

    expect(described_class.income.pluck(:kind)).to contain_exactly("rent", "rent_construction")
  end
end
