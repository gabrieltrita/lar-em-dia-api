# 2FA por TOTP (Google Authenticator, 1Password, Authy...) + códigos de backup.
module TwoFactorAuthenticatable
  extend ActiveSupport::Concern

  OTP_ISSUER = "Trita".freeze
  OTP_DRIFT = 30 # segundos de tolerância para relógio dessincronizado
  BACKUP_CODES_COUNT = 10

  def two_factor_enabled?
    otp_enabled_at.present?
  end

  # Admins são obrigados a ter 2FA para acessar a área administrativa.
  def two_factor_setup_required?
    admin? && !two_factor_enabled?
  end

  def generate_otp_secret!
    update!(otp_secret: ROTP::Base32.random, otp_enabled_at: nil, otp_last_used_step: nil)
  end

  def otp_provisioning_uri
    totp.provisioning_uri(email)
  end

  # Retorna os códigos de backup (exibidos UMA única vez) ou nil se o código for inválido.
  def enable_two_factor!(code)
    return if otp_secret.blank? || two_factor_enabled?
    return unless verify_otp(code)

    codes = new_backup_codes
    update!(otp_enabled_at: Time.current, otp_backup_code_digests: codes.map { |c| backup_code_digest(c) })
    codes
  end

  def disable_two_factor!
    update!(otp_secret: nil, otp_enabled_at: nil, otp_last_used_step: nil, otp_backup_code_digests: [])
  end

  def regenerate_backup_codes!
    codes = new_backup_codes
    update!(otp_backup_code_digests: codes.map { |c| backup_code_digest(c) })
    codes
  end

  def backup_codes_remaining
    otp_backup_code_digests.size
  end

  # Aceita código TOTP ou código de backup (que é consumido).
  def verify_second_factor(code)
    verify_otp(code) || consume_backup_code(code)
  end

  # TOTP com proteção contra replay: um código já usado não vale de novo.
  def verify_otp(code)
    normalized = code.to_s.gsub(/\s/, "")
    return false if otp_secret.blank? || normalized !~ /\A\d{6}\z/

    timestamp = totp.verify(normalized, drift_behind: OTP_DRIFT, drift_ahead: OTP_DRIFT, after: otp_last_used_step)
    return false unless timestamp

    update_columns(otp_last_used_step: timestamp)
    true
  end

  private

  def totp
    ROTP::TOTP.new(otp_secret, issuer: OTP_ISSUER)
  end

  def consume_backup_code(code)
    normalized = code.to_s.downcase.gsub(/[^a-z0-9]/, "")
    return false if normalized.length != 10

    digest = backup_code_digest(normalized)
    match = otp_backup_code_digests.find { |stored| ActiveSupport::SecurityUtils.secure_compare(stored, digest) }
    return false unless match

    update_columns(otp_backup_code_digests: otp_backup_code_digests - [ match ])
    true
  end

  def new_backup_codes
    Array.new(BACKUP_CODES_COUNT) { SecureRandom.alphanumeric(10).downcase }
  end

  # HMAC com chave derivada do secret_key_base: um vazamento só do banco não
  # permite testar códigos offline.
  def backup_code_digest(code)
    key = Rails.application.key_generator.generate_key("trita/otp-backup-codes", 32)
    OpenSSL::HMAC.hexdigest("SHA256", key, code.to_s.downcase.gsub(/[^a-z0-9]/, ""))
  end
end
