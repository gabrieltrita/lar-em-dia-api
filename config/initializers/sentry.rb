require Rails.root.join("lib/sentry_config").to_s

if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    SentryConfig.apply(config)
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    config.release = ENV["APP_VERSION"]
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.0).to_f
  end
end
