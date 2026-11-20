class FundComposition < ApplicationRecord
  belongs_to :asset
  has_many :properties, class_name: "FundProperty", dependent: :delete_all, inverse_of: :fund_composition

  validates :reference_on, presence: true
  validates :asset_id, uniqueness: true
end
