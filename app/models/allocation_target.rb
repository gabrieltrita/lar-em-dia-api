class AllocationTarget < ApplicationRecord
  MAX_PERCENT_BPS = 10_000
  VALUES = { amount_cents: "fixed", percent_bps: "percent" }.freeze

  belongs_to :user
  belongs_to :reserve_account, optional: true
  has_many :allocations, foreign_key: :target_id, dependent: :delete_all, inverse_of: :target

  enum :mode, { fixed: "fixed", percent: "percent", remainder: "remainder" }, validate: true

  encrypts :name

  normalizes :name, with: ->(value) { value.strip.squish }

  before_validation :append_position, on: :create, unless: :position_changed?

  validates :name, presence: true, length: { maximum: 100 }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: Entry::MAX_AMOUNT_CENTS }, allow_nil: true
  validates :percent_bps, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_PERCENT_BPS }, allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :mode, uniqueness: { scope: :user_id }, if: :remainder?
  validate :values_match_mode
  validate :reserve_account_owned

  scope :ordered, -> { order(:position, :created_at) }

  private

  def append_position
    self.position = AllocationTarget.where(user_id: user_id).maximum(:position).to_i + 1
  end

  def values_match_mode
    VALUES.each do |attribute, value_mode|
      if mode == value_mode
        errors.add(attribute, :blank) if self[attribute].nil?
      elsif !self[attribute].nil?
        errors.add(attribute, :present)
      end
    end
  end

  def reserve_account_owned
    errors.add(:reserve_account_id, :required) if reserve_account_id && reserve_account&.user_id != user_id
  end
end
