class User < ApplicationRecord
  include TwoFactorAuthenticatable

  PASSWORD_FORMAT = /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+\z/
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  # Bloqueio progressivo: a partir da 5ª falha seguida, bloqueia 15 min,
  # dobrando a cada nova falha (30 min, 1h, ...) até no máximo 24h.
  MAX_FAILED_ATTEMPTS = 5
  BASE_LOCK_DURATION = 15.minutes
  MAX_LOCK_DURATION = 24.hours

  has_secure_password reset_token: false

  has_many :refresh_tokens, dependent: :delete_all
  has_many :consents, dependent: :delete_all

  # ===== Criptografia dos dados pessoais =====
  # e-mail: determinística para permitir busca exata e índice único.
  # demais campos: não-determinística (mais forte; não é possível buscar por eles no SQL).
  encrypts :email, deterministic: true, downcase: true
  encrypts :first_name, :last_name, :phone, :unconfirmed_email, :otp_secret

  # ===== Roles =====
  enum :role, { user: 0, admin: 1 }, default: :user, validate: true

  # Tokens assinados pelo Rails. O bloco define o que invalida o token:
  # se o valor mudar, o token deixa de valer (uso único).
  generates_token_for :password_reset, expires_in: 30.minutes do
    password_salt.last(10)
  end

  generates_token_for :email_confirmation, expires_in: 24.hours do
    [ email, confirmed_at ]
  end

  generates_token_for :email_change, expires_in: 24.hours do
    unconfirmed_email
  end

  normalizes :email, :unconfirmed_email, with: ->(email) { email.strip.downcase }
  normalizes :first_name, :last_name, with: ->(value) { value.strip.squish }
  normalizes :phone, with: ->(value) { value.gsub(/[^\d+]/, "") }

  validates :email, presence: true, uniqueness: true, format: { with: EMAIL_FORMAT }, length: { maximum: 255 }
  validates :unconfirmed_email, format: { with: EMAIL_FORMAT }, length: { maximum: 255 }, allow_nil: true
  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, length: { maximum: 100 }
  validates :phone, length: { maximum: 20 }
  validates :password, length: { minimum: 8, maximum: 72 }, format: { with: PASSWORD_FORMAT, message: :weak_password }, if: -> { password.present? }

  scope :not_anonymized, -> { where(anonymized_at: nil) }

  before_save :track_password_change, if: :will_save_change_to_password_digest?
  after_update_commit :on_password_changed, if: :saved_change_to_password_digest?
  after_update_commit :on_role_changed, if: :saved_change_to_role?
  after_update_commit :on_email_changed, if: :saved_change_to_email?

  def self.roles_list
    roles.keys
  end

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def anonymized?
    anonymized_at.present?
  end

  # ===== Confirmação de e-mail =====

  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current) unless confirmed?
  end

  def request_email_change!(new_email)
    update!(unconfirmed_email: new_email)
  end

  def confirm_email_change!
    raise ActiveRecord::RecordInvalid, self if unconfirmed_email.blank?

    self.email = unconfirmed_email
    self.unconfirmed_email = nil
    self.confirmed_at = Time.current
    save!
  end

  # ===== Sessões =====

  def track_sign_in!
    update_columns(last_sign_in_at: Time.current, sign_in_count: sign_in_count + 1)
  end

  # Encerra sessões: revoga os refresh tokens e bloqueia na hora os access
  # tokens já emitidos para essas sessões (denylist por sessão no Redis).
  def revoke_all_sessions!(except_family: nil)
    scope = refresh_tokens.active
    scope = scope.where.not(family_id: except_family) if except_family
    scope.distinct.pluck(:family_id).each { |family_id| Auth::TokenDenylist.revoke_session(family_id) }
    scope.update_all(revoked_at: Time.current)
  end

  def revoke_session!(family_id)
    Auth::TokenDenylist.revoke_session(family_id)
    refresh_tokens.where(family_id: family_id, revoked_at: nil).update_all(revoked_at: Time.current)
  end

  # ===== Bloqueio progressivo =====

  def access_locked?
    locked_until.present? && locked_until.future?
  end

  def register_failed_login!
    increment!(:failed_login_attempts, touch: false)
    return if failed_login_attempts < MAX_FAILED_ATTEMPTS

    exponent = [ failed_login_attempts - MAX_FAILED_ATTEMPTS, 10 ].min
    duration = [ BASE_LOCK_DURATION * (2**exponent), MAX_LOCK_DURATION ].min
    update_columns(locked_until: duration.from_now)

    AuditLog.record!("auth.locked", target: self, actor: nil, metadata: { attempts: failed_login_attempts, minutes: (duration / 60).to_i })
    UserMailer.account_locked(self).deliver_later
  end

  def reset_failed_logins!
    return if failed_login_attempts.zero? && locked_until.nil?

    update_columns(failed_login_attempts: 0, locked_until: nil)
  end
  alias_method :unlock!, :reset_failed_logins!

  # ===== LGPD =====

  # Em vez de apagar, remove todos os dados pessoais e mantém só o registro
  # técnico (id, datas, role) para preservar a integridade da auditoria.
  def anonymize!
    transaction do
      revoke_all_sessions!
      update_columns(
        email: "anon-#{id}@anonymized.invalid",
        first_name: "Usuário",
        last_name: "removido",
        phone: nil,
        unconfirmed_email: nil,
        otp_secret: nil,
        otp_enabled_at: nil,
        otp_last_used_step: nil,
        otp_backup_code_digests: [],
        password_digest: BCrypt::Password.create(SecureRandom.hex(32)),
        failed_login_attempts: 0,
        locked_until: nil,
        anonymized_at: Time.current,
        updated_at: Time.current
      )
    end
  end

  private

  def track_password_change
    self.password_changed_at = Time.current if persisted?
  end

  # Qualquer troca de senha (pelo usuário, por reset ou pelo admin)
  # derruba todas as sessões existentes e avisa o dono da conta.
  def on_password_changed
    revoke_all_sessions!
    reset_failed_logins!
    AuditLog.record!("user.password_changed", target: self)
    UserMailer.password_changed(self).deliver_later
  end

  def on_role_changed
    from, to = saved_change_to_role
    AuditLog.record!("user.role_changed", target: self, metadata: { from: from, to: to })
  end

  def on_email_changed
    AuditLog.record!("user.email_changed", target: self)
  end
end
