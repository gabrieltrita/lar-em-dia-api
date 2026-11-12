class ReserveMovement < ApplicationRecord
  belongs_to :user
  belongs_to :account, class_name: "ReserveAccount", inverse_of: :movements
  belongs_to :entry, optional: true

  enum :kind, { anchor: "anchor", deposit: "deposit", withdrawal: "withdrawal" }, validate: true

  attribute :debit_balance, :boolean, default: false

  validates :moved_on, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: Entry::MAX_AMOUNT_CENTS }
  validates :amount_cents, numericality: { greater_than: 0 }, unless: :anchor?
  validates :debit_balance, absence: { message: :anchor_not_allowed }, if: :anchor?
  validate :moved_on_not_in_future
  validate :account_stays_covered, if: :ledger_ready?

  scope :chronological, -> { order(:moved_on, :created_at) }

  private

  def moved_on_not_in_future
    errors.add(:moved_on, :in_future) if moved_on&.future?
  end

  def ledger_ready?
    account && errors.empty?
  end

  def account_stays_covered
    others = account.new_record? ? [] : account.movements.where.not(id: id).to_a
    errors.add(:amount_cents, :insufficient_reserve) if ReserveLedger.for(account, [ *others, self ]).shortfall?
  end
end
