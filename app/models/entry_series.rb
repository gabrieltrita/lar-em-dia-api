class EntrySeries < ApplicationRecord
  COUNT_RANGES = { "recurring" => (2..36), "installments" => (2..48) }.freeze
  DIRECTIONS = %w[forward backward].freeze

  belongs_to :user
  has_many :entries, -> { order(:series_position) }, foreign_key: :series_id, inverse_of: :series, dependent: :destroy

  enum :kind, { recurring: "recurring", installments: "installments" }, default: :recurring, validate: true

  attribute :direction, :string

  validates :entries_count, numericality: { only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: :maximum_count }
  validates :direction, inclusion: { in: DIRECTIONS }, on: :create
  validates :total_cents, numericality: { only_integer: true, greater_than_or_equal_to: :minimum_total_cents }, if: :installments?
  validates :total_cents, absence: true, unless: :installments?

  def maximum_count
    COUNT_RANGES.fetch(kind, COUNT_RANGES["recurring"]).max
  end

  def minimum_total_cents
    [ entries_count.to_i, 1 ].max
  end

  def installment_amounts
    share, rest = total_cents.divmod(entries_count)
    [ share + rest ] + Array.new(entries_count - 1, share)
  end
end
