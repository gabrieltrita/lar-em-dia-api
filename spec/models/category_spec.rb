require "rails_helper"

RSpec.describe Category do
  subject { build(:category) }

  it { is_expected.to have_many(:entries).dependent(:restrict_with_error) }
  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_uniqueness_of(:key) }
  it { is_expected.to validate_length_of(:key).is_at_most(50) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(100) }
  it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }
  it { is_expected.to allow_value("thirteenth_salary").for(:key) }
  it { is_expected.not_to allow_value("Salary", "1salary", "salary-bonus").for(:key) }

  it "requires a default nature on expense categories only" do
    expect(build(:category, :expense, default_nature: nil)).not_to be_valid
    expect(build(:category, :expense, default_nature: "sometimes")).not_to be_valid

    income = build(:category, default_nature: :fixed)
    expect(income).not_to be_valid
    expect(income.errors[:default_nature]).to eq([ "can only be set on expense categories" ])
  end

  it "rejects an unknown kind" do
    expect(build(:category, kind: "transfer")).not_to be_valid
  end

  it "lists only active categories, by kind and position" do
    second = create(:category, position: 1)
    first = create(:category, position: 0)
    expense = create(:category, :expense, position: 0)
    create(:category, :inactive)

    expect(described_class.active.ordered).to eq([ expense, first, second ])
  end

  it "cannot be deleted while entries use it" do
    category = create(:entry).category

    expect(category.destroy).to be(false)
    expect(category.errors.details[:base].first[:error]).to eq(:"restrict_dependent_destroy.has_many")
  end

  describe ".seed_defaults!" do
    it "creates the default income categories in order, once" do
      2.times { described_class.seed_defaults! }

      keys = described_class.income.order(:position).pluck(:key)
      expect(keys).to eq(described_class::DEFAULTS[:income].keys.map(&:to_s))
      expect(described_class.find_by(key: "salary")).to have_attributes(name: "Salary", position: 0, active: true)
    end

    it "creates the default expense categories with their nature" do
      described_class.seed_defaults!

      keys = described_class.expense.order(:position).pluck(:key)
      expect(keys).to eq(described_class::DEFAULTS[:expense].keys.map(&:to_s))
      expect(described_class.find_by(key: "housing")).to have_attributes(name: "Housing", default_nature: "fixed")
      expect(described_class.find_by(key: "groceries")).to have_attributes(name: "Groceries", default_nature: "variable")
      expect(described_class.income.pluck(:default_nature).uniq).to eq([ nil ])
    end

    it "keeps changes made to an existing category" do
      create(:category, key: "salary", name: "Wages", position: 5)

      described_class.seed_defaults!

      expect(described_class.find_by(key: "salary")).to have_attributes(name: "Wages", position: 5)
    end
  end
end
