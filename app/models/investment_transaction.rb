class InvestmentTransaction < ApplicationRecord
  MAX_QUANTITY = 1_000_000_000
  TRADES = %w[buy sell].freeze

  belongs_to :user
  belongs_to :position, class_name: "InvestmentPosition", optional: true, inverse_of: :transactions
  belongs_to :entry, optional: true

  enum :kind, { buy: "buy", sell: "sell", split: "split", reverse_split: "reverse_split", bonus: "bonus" }, scopes: false, validate: true

  attribute :debit_balance, :boolean, default: false

  validates :traded_on, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_QUANTITY }
  validates :price_cents, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: Entry::MAX_AMOUNT_CENTS }, if: :trade?
  validates :price_cents, absence: { message: :only_for_trades }, unless: :trade?
  validates :fees_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: Entry::MAX_AMOUNT_CENTS }
  validates :fees_cents, numericality: { equal_to: 0, message: :only_for_trades }, unless: :trade?
  validates :debit_balance, absence: { message: :only_for_trades }, unless: :trade?
  validate :asset_known
  validate :traded_on_not_in_future
  validate :position_stays_covered, if: :ledger_ready?

  scope :chronological, -> { order(:traded_on, :created_at) }

  def ticker
    position&.ticker
  end

  def trade?
    TRADES.include?(kind)
  end

  def amount_cents
    gross = quantity * price_cents
    buy? ? gross + fees_cents : gross - fees_cents
  end

  private

  def asset_known
    errors.add(:ticker, :unknown_asset) unless position
  end

  def traded_on_not_in_future
    errors.add(:traded_on, :in_future) if traded_on&.future?
  end

  def ledger_ready?
    position && errors.empty?
  end

  def position_stays_covered
    others = position.new_record? ? [] : position.transactions.where.not(id: id).to_a
    errors.add(:quantity, :insufficient_quantity) if PositionLedger.new([ *others, self ]).shortfall?
  end
end
