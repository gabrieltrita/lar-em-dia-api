class Allocation < ApplicationRecord
  belongs_to :user
  belongs_to :target, class_name: "AllocationTarget", inverse_of: :allocations
  belongs_to :entry, optional: true

  attribute :amount_cents, :integer

  normalizes :month, with: ->(value) { value.beginning_of_month }

  validates :month, presence: true, uniqueness: { scope: :target_id }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: Entry::MAX_AMOUNT_CENTS }, on: :create
  validate :month_not_in_future

  scope :chronological, -> { order(:month, :created_at) }

  def used_on
    [ Date.current, month.end_of_month ].min
  end

  private

  def month_not_in_future
    errors.add(:month, :in_future) if month && month > Date.current
  end
end
