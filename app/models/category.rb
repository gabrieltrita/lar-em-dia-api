class Category < ApplicationRecord
  KEY_FORMAT = /\A[a-z][a-z0-9_]*\z/

  DEFAULTS = {
    income: {
      salary: "Salary",
      thirteenth_salary: "13th salary",
      vacation_bonus: "Vacation bonus",
      bonus: "Bonus and profit sharing",
      extra_income: "Extra income",
      rent_received: "Rent received",
      alimony_received: "Alimony received",
      tax_refund: "Tax refund",
      reimbursement: "Reimbursement",
      other_income: "Other income",
      investment_redemption: "Investment redemption"
    },
    expense: {
      housing: "Housing",
      utilities: "Utilities",
      internet_phone: "Internet and phone",
      subscriptions: "Subscriptions",
      education: "Education",
      insurance: "Insurance",
      health_plan: "Health plan",
      loans: "Loans",
      groceries: "Groceries",
      restaurants: "Restaurants",
      transport: "Transport",
      health: "Health",
      leisure: "Leisure",
      travel: "Travel",
      clothing: "Clothing",
      personal_care: "Personal care",
      pets: "Pets",
      gifts_donations: "Gifts and donations",
      taxes_fees: "Taxes and fees",
      other_expense: "Other expense",
      investment_contribution: "Investment contribution"
    }
  }.freeze

  FIXED_EXPENSES = %i[housing utilities internet_phone subscriptions education insurance health_plan loans].freeze

  enum :kind, { income: "income", expense: "expense" }, validate: true
  enum :default_nature, { fixed: "fixed", variable: "variable" }, prefix: :default, validate: { allow_nil: true }

  has_many :entries, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true, format: { with: KEY_FORMAT }, length: { maximum: 50 }
  validates :name, presence: true, length: { maximum: 100 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :default_nature, presence: true, if: :expense?
  validates :default_nature, absence: { message: :only_for_expenses }, if: :income?
  validate :key_and_kind_unchanged, on: :update

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:kind, :position, :key) }

  def self.seed_defaults!
    DEFAULTS.each do |kind, categories|
      categories.each_with_index do |(key, name), position|
        find_or_create_by!(key: key.to_s) do |category|
          category.assign_attributes(kind: kind, name: name, position: position, default_nature: default_nature_for(kind, key))
        end
      end
    end
  end

  def self.default_nature_for(kind, key)
    return if kind == :income

    FIXED_EXPENSES.include?(key) ? "fixed" : "variable"
  end

  private

  def key_and_kind_unchanged
    %i[key kind].each { |attribute| errors.add(attribute, :immutable) if attribute_changed?(attribute) }
  end
end
