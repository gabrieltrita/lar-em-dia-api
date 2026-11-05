class NotificationSettingsBlueprint < Blueprinter::Base
  fields :due_alerts_enabled, :due_alert_days_before
end
