class DueAlertsJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    zones = User.time_zones_at_hour(DueAlertable::SEND_HOUR, now: now)
    sent = 0
    User.receiving_due_alerts.where(time_zone: zones).find_each do |user|
      sent += 1 if alert(user, user.local_date(now))
    end
    Rails.logger.info({ job: self.class.name, zones: zones.size, sent: sent })
  end

  private

  def alert(user, today)
    return false if user.due_alerts_sent_on == today || !user.due_alert_entries(on: today).exists?

    user.update_columns(due_alerts_sent_on: today)
    DueAlertMailer.upcoming(user).deliver_later
    true
  end
end
