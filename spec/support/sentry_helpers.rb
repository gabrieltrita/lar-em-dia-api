require "sentry/rails/breadcrumb/active_support_logger"

module SentryHelpers
  def with_sentry
    Sentry.init do |config|
      SentryConfig.apply(config)
      config.dsn = "http://public@sentry.test/1"
      config.transport.transport_class = Sentry::DummyTransport
      config.background_worker_threads = 0
    end
    Sentry::Rails::Breadcrumb::ActiveSupportLogger.inject(Sentry.configuration.rails.active_support_logger_subscription_items)
    yield Sentry.get_current_client.transport
  ensure
    Sentry::Rails::Breadcrumb::ActiveSupportLogger.detach
    Sentry.close
  end

  def sentry_payload(event)
    payload = event.to_json_compatible
    %w[exception threads].each { |key| payload.dig(key, "values")&.each { |value| value.delete("stacktrace") } }
    payload.to_json
  end
end

RSpec.configure do |config|
  config.include SentryHelpers
end
