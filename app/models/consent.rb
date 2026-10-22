# Registro histórico (LGPD) de aceite/revogação de termos. Nunca é editado:
# cada mudança gera uma nova linha; o estado atual é a linha mais recente por tipo.
class Consent < ApplicationRecord
  KINDS = {
    "terms" => { required: true },
    "privacy" => { required: true },
    "marketing" => { required: false }
  }.freeze

  belongs_to :user

  encrypts :ip_address, :user_agent

  validates :kind, inclusion: { in: KINDS.keys }
  validates :version, presence: true
  validates :granted, inclusion: { in: [ true, false ] }

  def readonly?
    persisted?
  end

  def self.current_version(kind)
    ENV.fetch("#{kind.upcase}_VERSION", "1.0")
  end

  def self.required_kinds
    KINDS.select { |_, opts| opts[:required] }.keys
  end

  def self.record!(user, kind, granted)
    user.consents.create!(
      kind: kind,
      version: current_version(kind),
      granted: granted,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent&.truncate(500)
    )
  end

  # Estado atual por tipo: { "terms" => { granted:, version:, at: }, ... }
  def self.status_for(user)
    latest = user.consents.select("DISTINCT ON (kind) *").order(:kind, created_at: :desc)
    KINDS.keys.index_with do |kind|
      record = latest.find { |c| c.kind == kind }
      { granted: record&.granted || false, version: record&.version, at: record&.created_at, current_version: current_version(kind) }
    end
  end
end
