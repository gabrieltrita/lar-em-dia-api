class RefreshToken < ApplicationRecord
  belongs_to :user

  encrypts :user_agent, :ip_address

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.digest(raw_token)
    OpenSSL::Digest::SHA256.hexdigest(raw_token.to_s)
  end

  def self.find_by_raw_token(raw_token)
    return if raw_token.blank?

    find_by(token_digest: digest(raw_token))
  end

  # Uma linha por sessão (dispositivo), com a atividade mais recente.
  def self.sessions_for(user)
    user.refresh_tokens.active
      .select("DISTINCT ON (family_id) *")
      .order(:family_id, created_at: :desc)
      .sort_by(&:created_at).reverse
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at <= Time.current
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked?
  end
end
