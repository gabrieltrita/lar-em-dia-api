class FundReport < ApplicationRecord
  CATEGORIES = %w[brick paper fund_of_funds hybrid].freeze

  belongs_to :asset

  validates :reference_month, presence: true, uniqueness: { scope: :asset_id }
  validates :equity_cents, :book_value_per_share_e8, :shares_count, :shareholders_count, numericality: { only_integer: true }
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
end
