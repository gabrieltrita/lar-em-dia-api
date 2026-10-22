class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "Trita <no-reply@trita.dev>") }
  layout "mailer"

  private

  def frontend_url(path = "")
    "#{ENV.fetch("FRONTEND_URL", "http://localhost:5173")}#{path}"
  end
end
