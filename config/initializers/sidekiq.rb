redis_config = { url: ENV.fetch("SIDEKIQ_REDIS_URL", "redis://localhost:6379/0") }

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# Carrega os jobs agendados de config/schedule.yml ao subir o Sidekiq.
Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = "config/schedule.yml"
end
