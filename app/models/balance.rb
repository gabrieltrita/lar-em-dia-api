class Balance < ApplicationRecord
  belongs_to :user

  validates :amount_cents, presence: true,
                           numericality: { only_integer: true, greater_than_or_equal_to: -Entry::MAX_AMOUNT_CENTS, less_than_or_equal_to: Entry::MAX_AMOUNT_CENTS }
  validates :as_of, presence: true, uniqueness: { scope: :user_id }
  validate :as_of_not_in_future

  scope :recent, -> { order(as_of: :desc) }

  private

  def as_of_not_in_future
    errors.add(:as_of, :in_future) if as_of&.future?
  end
end
