class FundProperty < ApplicationRecord
  belongs_to :fund_composition

  enum :kind, { rent: "rent", rent_construction: "rent_construction", sale: "sale", sale_construction: "sale_construction" }, validate: true

  validates :name, presence: true, length: { maximum: Asset::NAME_LIMIT }

  scope :income, -> { where(kind: %w[rent rent_construction]) }
end
