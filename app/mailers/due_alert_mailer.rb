class DueAlertMailer < ApplicationMailer
  helper :due_alert

  def upcoming(user)
    @user = user
    @entries = user.due_alert_entries.to_a
    @due_on = user.due_alerts_sent_on + user.due_alert_days_before
    @expenses_url = frontend_url("/expenses")
    @unsubscribe_url = frontend_url("/unsubscribe?token=#{CGI.escape(user.generate_token_for(:due_alerts_unsubscribe))}")
    mail to: @user.email, subject: subject_for(user.due_alert_days_before)
  end

  private

  def subject_for(days)
    case days
    when 0 then "Bills due today"
    when 1 then "Bills due tomorrow"
    else "Bills due in #{days} days"
    end
  end
end
