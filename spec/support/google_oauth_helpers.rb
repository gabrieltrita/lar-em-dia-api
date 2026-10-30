module GoogleOauthHelpers
  GOOGLE_CLIENT_ID = "web-client.apps.googleusercontent.com".freeze
  GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs".freeze
  GOOGLE_KEYS = Hash.new { |keys, kid| keys[kid] = OpenSSL::PKey::RSA.generate(2048) }

  def google_key(kid = "kid-1")
    GOOGLE_KEYS[kid]
  end

  def google_jwks(*kids)
    { keys: kids.map { |kid| JWT::JWK.new(google_key(kid), kid: kid).export } }.to_json
  end

  def stub_google_jwks(*kids, headers: {})
    kids = [ "kid-1" ] if kids.empty?
    stub_request(:get, GOOGLE_JWKS_URL).to_return(status: 200, body: google_jwks(*kids), headers: headers)
  end

  def google_claims(overrides = {})
    {
      iss: "https://accounts.google.com",
      aud: GOOGLE_CLIENT_ID,
      sub: "google-sub-1",
      email: "person@example.com",
      email_verified: true,
      given_name: "Person",
      family_name: "Example",
      iat: Time.now.to_i,
      exp: 1.hour.from_now.to_i
    }.merge(overrides).compact
  end

  def google_id_token(kid: "kid-1", **overrides)
    JWT.encode(google_claims(overrides), google_key(kid), "RS256", { kid: kid })
  end
end

RSpec.shared_context "with google oauth" do
  include GoogleOauthHelpers

  around do |example|
    original = ENV["GOOGLE_CLIENT_IDS"]
    ENV["GOOGLE_CLIENT_IDS"] = "#{GoogleOauthHelpers::GOOGLE_CLIENT_ID},ios-client.apps.googleusercontent.com"
    example.run
  ensure
    original ? ENV["GOOGLE_CLIENT_IDS"] = original : ENV.delete("GOOGLE_CLIENT_IDS")
  end

  before { stub_google_jwks }
end
