# Proteção contra brute force e abuso.
class Rack::Attack
  Rack::Attack.enabled = !Rails.env.test? || ENV["RACK_ATTACK_ENABLED"] == "true"

  Rack::Attack.cache.store = Rails.cache

  AUTH_SENSITIVE_PATHS = %w[
    /api/v1/auth/register
    /api/v1/auth/password/forgot
    /api/v1/auth/password/reset
    /api/v1/auth/confirm
    /api/v1/auth/confirm/resend
    /api/v1/auth/email/confirm
  ].freeze

  REAUTH_PATHS = %w[
    /api/v1/me/password
    /api/v1/me/email
    /api/v1/me/two_factor/setup
    /api/v1/me/two_factor/enable
    /api/v1/me/two_factor/backup_codes
  ].freeze

  # O Rack::Attack roda antes do Rails processar o JSON, então lemos o corpo
  # aqui (e devolvemos o "cursor" ao início para o Rails ler depois).
  def self.json_param(req, key)
    return unless req.media_type == "application/json"

    body = req.body.read
    req.body.rewind
    JSON.parse(body)[key] if body.present?
  rescue JSON::ParserError, NoMethodError
    nil
  end

  def self.normalized_email(req)
    (json_param(req, "email") || req.params["email"]).to_s.downcase.strip.presence
  end

  # Limite geral por IP
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path == "/up"
  end

  # Login: por IP e por e-mail (o bloqueio de conta no model é a 2ª camada)
  throttle("auth/login/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  throttle("auth/login/email", limit: 5, period: 1.minute) do |req|
    normalized_email(req) if req.path == "/api/v1/auth/login" && req.post?
  end

  # 2º fator: 6 dígitos = 1 milhão de combinações; limitar é essencial
  throttle("auth/two_factor/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/two_factor" && req.post?
  end

  throttle("auth/refresh/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/refresh" && req.post?
  end

  # Cadastro, confirmação e recuperação de senha
  throttle("auth/sensitive/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.post? && AUTH_SENSITIVE_PATHS.include?(req.path)
  end

  throttle("auth/sensitive/email", limit: 3, period: 15.minutes) do |req|
    if req.post? && %w[/api/v1/auth/password/forgot /api/v1/auth/confirm/resend /api/v1/auth/register].include?(req.path)
      normalized_email(req)
    end
  end

  # Ações que pedem senha atual / código 2FA (token roubado não força a senha)
  throttle("me/reauth/ip", limit: 5, period: 1.minute) do |req|
    req.ip if (req.post? || req.patch? || req.delete?) && (REAUTH_PATHS.include?(req.path) || req.path.start_with?("/api/v1/me/two_factor") || (req.delete? && req.path == "/api/v1/me"))
  end

  self.throttled_responder = lambda do |_req|
    body = { error: { code: "rate_limited", message: "Muitas requisições. Tente novamente em instantes." } }
    [ 429, { "Content-Type" => "application/json", "Retry-After" => "60" }, [ body.to_json ] ]
  end
end
