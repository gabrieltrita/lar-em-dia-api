class Identity < ApplicationRecord
  EMAIL_FORMAT = User::EMAIL_FORMAT

  belongs_to :user

  encrypts :provider_uid, deterministic: true
  encrypts :email_at_link

  enum :provider, { google: "google", apple: "apple" }, validate: true

  normalizes :email_at_link, with: ->(email) { email.strip.downcase }

  validates :provider_uid, presence: true, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :user_id }
  validates :email_at_link, format: { with: EMAIL_FORMAT }, length: { maximum: 255 }, allow_nil: true
end
