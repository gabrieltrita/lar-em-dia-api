module SentryConfig
  FILTERED = "[FILTERED]".freeze
  REMOVED_HEADERS = %w[Authorization Cookie Set-Cookie X-Token-Transport User-Agent].freeze
  RACK_ENV_ALLOWED = %w[SERVER_NAME SERVER_PORT].freeze
  CACHE_EVENTS = %w[cache_read cache_generate cache_fetch_hit cache_write cache_delete cache_exist?].freeze
  BREADCRUMB_KEYS = CACHE_EVENTS.to_h { |name| [ "#{name}.active_support", %i[store hit] ] }
    .merge("sql.active_record" => %i[name statement_name cached]).freeze

  def self.apply(config)
    config.send_default_pii = false
    config.rack_env_whitelist = RACK_ENV_ALLOWED
    config.breadcrumbs_logger = %i[active_support_logger http_logger]
    config.rails.active_support_logger_subscription_items.merge!(BREADCRUMB_KEYS)
    config.before_send = method(:scrub)
  end

  def self.scrub(event, _hint)
    event.user = event.user.slice(:id, "id")
    event.request&.headers&.reject! { |name, _| REMOVED_HEADERS.any? { |header| header.casecmp?(name) } }
    Array(event.exception&.values).each { |exception| exception.value = FILTERED }
    event.message = FILTERED if event.message.present?
    event.contexts[:sidekiq]&.delete("args")
    event
  end
end
