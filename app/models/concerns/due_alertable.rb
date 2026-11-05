module DueAlertable
  extend ActiveSupport::Concern

  DAYS_BEFORE = (0..7)
  SEND_HOUR = 8
  UNSUBSCRIBE_TOKEN_TTL = 60.days

  included do
    validates :due_alerts_enabled, inclusion: { in: [ true, false ] }
    validates :due_alert_days_before, inclusion: { in: DAYS_BEFORE }

    generates_token_for :due_alerts_unsubscribe, expires_in: UNSUBSCRIBE_TOKEN_TTL

    scope :receiving_due_alerts, -> { not_anonymized.where(due_alerts_enabled: true, deactivated_at: nil).where.not(confirmed_at: nil) }
  end

  class_methods do
    def time_zones_at_hour(hour, now: Time.current)
      User::TIME_ZONES.select { |zone| now.in_time_zone(zone).hour == hour }
    end
  end

  def local_date(now = Time.current)
    now.in_time_zone(time_zone).to_date
  end

  def due_alert_entries(on: due_alerts_sent_on)
    entries.expense.pending.where(due_on: on + due_alert_days_before).chronological
  end
end
