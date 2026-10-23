Rails.application.configure do
  config.lograge.enabled = config.x.json_logs
  config.lograge.formatter = Lograge::Formatters::Raw.new
  config.lograge.ignore_actions = [ "Rails::HealthController#show", "HealthController#show" ]
  config.lograge.custom_options = lambda do |event|
    { request_id: event.payload[:request_id], user_id: event.payload[:user_id], error: event.payload[:exception]&.first }.compact
  end
end
