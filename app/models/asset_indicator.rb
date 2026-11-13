class AssetIndicator < ApplicationRecord
  belongs_to :asset

  validates :computed_on, presence: true
end
