class AssetQuote < ApplicationRecord
  belongs_to :asset, inverse_of: :quotes

  validates :quoted_on, presence: true, uniqueness: { scope: :asset_id }
  validates :close_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :volume_cents, :trades_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
