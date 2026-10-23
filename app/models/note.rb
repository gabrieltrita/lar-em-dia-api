class Note < ApplicationRecord
  belongs_to :user

  encrypts :title, :body

  normalizes :title, with: ->(value) { value.squish }

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 10_000 }

  scope :recent, -> { order(created_at: :desc) }
end
