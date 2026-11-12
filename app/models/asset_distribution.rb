class AssetDistribution < ApplicationRecord
  E8_PER_CENT = 1_000_000
  JCP_NET_RATE = Rational(85, 100)
  MAX_AMOUNT_PER_SHARE_E8 = 100_000_000_000_000
  MANUAL_KINDS = %w[dividend jcp].freeze

  belongs_to :asset
  belongs_to :user, optional: true

  enum :kind, { fii_income: "fii_income", dividend: "dividend", jcp: "jcp" }, validate: true
  enum :source, { cvm: "cvm", manual: "manual" }, validate: true

  validates :record_on, presence: true
  validates :amount_per_share_e8, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_AMOUNT_PER_SHARE_E8 }
  validates :paid_on, presence: true, if: :manual?
  validates :kind, inclusion: { in: MANUAL_KINDS }, if: :manual?
  validate :paid_on_after_record_on
  validate :asset_held, if: :manual?

  scope :visible_to, ->(user) { where(user_id: [ nil, user.id ]) }
  scope :newest_first, -> { order(record_on: :desc, created_at: :desc) }

  def ticker
    asset&.ticker
  end

  def net_amount_per_share_e8
    net_per_share_e8.round
  end

  def net_per_share_e8
    jcp? ? amount_per_share_e8 * JCP_NET_RATE : Rational(amount_per_share_e8)
  end

  def payment_month
    (paid_on || record_on.next_month).beginning_of_month
  end

  private

  def paid_on_after_record_on
    errors.add(:paid_on, :before_record_on) if paid_on && record_on && paid_on < record_on
  end

  def asset_held
    return errors.add(:ticker, :unknown_asset) unless asset && user.investment_positions.exists?(asset: asset)

    errors.add(:ticker, :stock_only) unless asset.stock?
  end
end
