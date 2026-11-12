redis_config = { url: ENV.fetch("SIDEKIQ_REDIS_URL", "redis://localhost:6379/0") }

Sidekiq.configure_server do |config|
  config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new if Rails.application.config.x.json_logs
  config.redis = redis_config
  config.on(:startup) { CronSchedule.remove_disabled! }
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = "config/schedule.yml"
end
