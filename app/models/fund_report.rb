class FundReport < ApplicationRecord
  belongs_to :asset

  validates :reference_month, presence: true, uniqueness: { scope: :asset_id }
  validates :equity_cents, :book_value_per_share_e8, :shares_count, :shareholders_count, numericality: { only_integer: true }
end
