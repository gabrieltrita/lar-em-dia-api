class AssetQuote < ApplicationRecord
  belongs_to :asset, inverse_of: :quotes

  validates :quoted_on, presence: true, uniqueness: { scope: :asset_id }
  validates :close_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :volume_cents, :trades_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.latest_per_asset(asset_ids)
    where(asset_id: asset_ids).select("DISTINCT ON (asset_id) asset_quotes.*").order(:asset_id, quoted_on: :desc)
  end

  def self.month_end_closes(asset_ids, until_date)
    where(asset_id: asset_ids, quoted_on: ..until_date)
      .select("DISTINCT ON (asset_id, date_trunc('month', quoted_on)) asset_id, quoted_on, close_cents")
      .order(Arel.sql("asset_id, date_trunc('month', quoted_on), quoted_on DESC"))
  end
end
