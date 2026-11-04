class EntrySeries < ApplicationRecord
  COUNT_RANGE = (2..36)
  DIRECTIONS = %w[forward backward].freeze

  belongs_to :user
  has_many :entries, -> { order(:series_position) }, foreign_key: :series_id, inverse_of: :series, dependent: :destroy

  enum :kind, { recurring: "recurring" }, default: :recurring, validate: true

  attribute :direction, :string

  validates :entries_count, numericality: { only_integer: true, greater_than_or_equal_to: COUNT_RANGE.min, less_than_or_equal_to: COUNT_RANGE.max }
  validates :direction, inclusion: { in: DIRECTIONS }, on: :create
end
