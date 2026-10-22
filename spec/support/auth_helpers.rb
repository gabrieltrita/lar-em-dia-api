module AuthHelpers
  def json
    JSON.parse(response.body)
  end

  def tokens_for(user)
    Auth::TokenIssuer.call(user)
  end

  def auth_headers(user, tokens: nil)
    { "Authorization" => "Bearer #{(tokens || tokens_for(user))[:access_token]}" }
  end

  def bearer(access_token)
    { "Authorization" => "Bearer #{access_token}" }
  end

  def otp_code(user, at: Time.current)
    ROTP::TOTP.new(user.reload.otp_secret).at(at)
  end

  def login(email, password, headers: {})
    post "/api/v1/auth/login", params: { email: email, password: password }, headers: headers, as: :json
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include AuthHelpers, type: :model
  config.include ActiveJob::TestHelper
  config.include ActiveSupport::Testing::TimeHelpers
  config.before { Rails.cache.clear }
end
