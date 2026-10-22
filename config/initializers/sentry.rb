# Monitoramento de erros. Só liga se SENTRY_DSN estiver definido.
# Nenhum dado pessoal é enviado: só o id do usuário.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.release = ENV["APP_VERSION"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
    config.send_default_pii = false
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.0).to_f

    sensitive_headers = %w[Authorization Cookie Set-Cookie X-Token-Transport]

    config.before_send = lambda do |event, _hint|
      event.user = event.user&.slice(:id, "id") || {}

      if event.request
        event.request.data = "[FILTERED]" if event.request.data.present?
        event.request.cookies = {}
        event.request.headers&.reject! { |k, _| sensitive_headers.any? { |h| h.casecmp?(k) } }
        # Query string pode ter token de reset/confirmação
        event.request.query_string = "[FILTERED]" if event.request.query_string.present?
      end

      event
    end
  end
end
