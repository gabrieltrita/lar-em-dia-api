require "sidekiq/web"
require "rack/session"

Sidekiq::Web.use Rack::Session::Cookie,
  secret: Rails.application.secret_key_base,
  same_site: true,
  max_age: 86_400

Sidekiq::Web.use Rack::Auth::Basic, "Sidekiq" do |username, password|
  expected_user = ENV["SIDEKIQ_WEB_USERNAME"].to_s
  expected_pass = ENV["SIDEKIQ_WEB_PASSWORD"].to_s

  expected_user.present? && expected_pass.present? &&
    ActiveSupport::SecurityUtils.secure_compare(username, expected_user) &
      ActiveSupport::SecurityUtils.secure_compare(password, expected_pass)
end
