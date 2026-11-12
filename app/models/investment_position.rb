class InvestmentPosition < ApplicationRecord
  DEFAULT_GOALS = { "fii" => "income", "stock" => "growth" }.freeze

  belongs_to :user
  belongs_to :asset
  has_many :transactions, class_name: "InvestmentTransaction", foreign_key: :position_id, dependent: :destroy, inverse_of: :position

  enum :goal, { income: "income", growth: "growth" }, validate: true

  validates :asset_id, uniqueness: { scope: :user_id }

  before_validation { self.goal ||= DEFAULT_GOALS[asset&.asset_type] }

  delegate :ticker, to: :asset
end
