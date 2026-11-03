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
      other_income: "Other income"
    }
  }.freeze

  enum :kind, { income: "income", expense: "expense" }, validate: true

  has_many :entries, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true, format: { with: KEY_FORMAT }, length: { maximum: 50 }
  validates :name, presence: true, length: { maximum: 100 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:kind, :position, :key) }

  def self.seed_defaults!
    DEFAULTS.each do |kind, categories|
      categories.each_with_index do |(key, name), position|
        find_or_create_by!(key: key.to_s) do |category|
          category.assign_attributes(kind: kind, name: name, position: position)
        end
      end
    end
  end
end
