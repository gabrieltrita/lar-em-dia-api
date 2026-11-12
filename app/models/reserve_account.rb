class ReserveAccount < ApplicationRecord
  MAX_CDI_PERCENT_BPS = 50_000
  MAX_ANNUAL_RATE_BPS = 10_000
  RATES = { cdi_percent_bps: "cdb", annual_rate_bps: "fixed_rate" }.freeze

  belongs_to :user
  has_many :movements, class_name: "ReserveMovement", foreign_key: :account_id, dependent: :delete_all, inverse_of: :account

  enum :kind, { selic_treasury: "selic_treasury", cdb: "cdb", savings: "savings", idle: "idle", fixed_rate: "fixed_rate" }, validate: true

  encrypts :name

  normalizes :name, with: ->(value) { value.strip.squish }

  validates :name, presence: true, length: { maximum: 100 }
  validates :cdi_percent_bps, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_CDI_PERCENT_BPS }, allow_nil: true
  validates :annual_rate_bps, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_ANNUAL_RATE_BPS }, allow_nil: true
  validate :rates_match_kind

  scope :ordered, -> { order(:created_at) }

  def exempt?
    tax_exempt || savings? || idle?
  end

  def destroy_with_entries!
    transaction do
      entry_ids = movements.where.not(entry_id: nil).pluck(:entry_id)
      destroy!
      Entry.where(id: entry_ids).destroy_all
    end
  end

  private

  def rates_match_kind
    RATES.each do |attribute, rate_kind|
      if kind == rate_kind
        errors.add(attribute, :rate_required) if self[attribute].nil?
      elsif !self[attribute].nil?
        errors.add(attribute, :rate_not_allowed)
      end
    end
  end
end
