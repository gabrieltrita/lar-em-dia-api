class Entry < ApplicationRecord
  MAX_AMOUNT_CENTS = 10_000_000_000_000

  belongs_to :user
  belongs_to :category
  belongs_to :series, class_name: "EntrySeries", optional: true, inverse_of: :entries
  has_one :investment_transaction, dependent: :nullify

  enum :kind, { income: "income", expense: "expense" }, validate: true
  enum :status, { pending: "pending", paid: "paid" }, default: :pending, validate: true
  enum :nature, { fixed: "fixed", variable: "variable" }, validate: { allow_nil: true }

  encrypts :description

  before_validation :copy_kind_from_category
  before_validation :default_nature_from_category

  validates :description, presence: true, length: { maximum: 200 }
  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_AMOUNT_CENTS }
  validates :due_on, presence: true
  validates :paid_on, absence: { message: :only_when_paid }, unless: :paid?
  validates :nature, presence: true, if: :expense?
  validates :nature, absence: { message: :only_for_expenses }, if: :income?
  validate :category_active, if: :category_id_changed?

  scope :chronological, -> { order(:due_on, :created_at) }

  private

  def copy_kind_from_category
    self.kind = category.kind if category
  end

  def default_nature_from_category
    self.nature ||= category&.default_nature if expense?
  end

  def category_active
    errors.add(:category, :inactive) if category && !category.active?
  end
end
