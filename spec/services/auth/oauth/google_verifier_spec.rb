require "rails_helper"

RSpec.describe Auth::Oauth::GoogleVerifier do
  include_context "with google oauth"

  def verify(token)
    described_class.call(token)
  end

  def error_code
    verify(yield)
  rescue Auth::Unauthorized => e
    e.code
  end

  it "returns the verified claims" do
    claims = verify(google_id_token)

    expect(claims).to have_attributes(sub: "google-sub-1", email: "person@example.com", given_name: "Person", family_name: "Example")
  end

  it "accepts the second issuer form, another configured client and a string email_verified" do
    token = google_id_token(iss: "accounts.google.com", aud: "ios-client.apps.googleusercontent.com", email_verified: "true")
    expect(verify(token).email).to eq("person@example.com")
  end

  it "rejects an expired token" do
    expect(error_code { google_id_token(exp: 1.minute.ago.to_i) }).to eq("oauth_token_invalid")
  end

  it "rejects a token for another client" do
    expect(error_code { google_id_token(aud: "someone-else") }).to eq("oauth_token_invalid")
  end

  it "rejects another issuer" do
    expect(error_code { google_id_token(iss: "https://evil.example.com") }).to eq("oauth_token_invalid")
  end

  it "rejects a token signed with another key" do
    forged = JWT.encode(google_claims, google_key("attacker"), "RS256", { kid: "kid-1" })
    expect(error_code { forged }).to eq("oauth_token_invalid")
  end

  it "rejects algorithm confusion and unsigned tokens" do
    hmac = JWT.encode(google_claims, "secret", "HS256", { kid: "kid-1" })
    unsigned = JWT.encode(google_claims, nil, "none", { kid: "kid-1" })

    expect(error_code { hmac }).to eq("oauth_token_invalid")
    expect(error_code { unsigned }).to eq("oauth_token_invalid")
  end

  it "rejects garbage and a missing token" do
    expect(error_code { "not-a-token" }).to eq("oauth_token_invalid")
    expect(error_code { nil }).to eq("oauth_token_invalid")
  end

  it "rejects every token when no client id is configured" do
    ENV["GOOGLE_CLIENT_IDS"] = ""
    expect(error_code { google_id_token }).to eq("oauth_token_invalid")
  end

  it "rejects an unverified or missing email" do
    expect(error_code { google_id_token(email_verified: false) }).to eq("oauth_email_unverified")
    expect(error_code { google_id_token(email_verified: nil) }).to eq("oauth_email_unverified")
    expect(error_code { google_id_token(email: nil) }).to eq("oauth_email_unverified")
  end

  describe "signing keys" do
    it "fetches them once and serves the next verifications from the cache" do
      2.times { verify(google_id_token) }
      expect(a_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL)).to have_been_made.once
    end

    it "refetches after the max-age from Google" do
      stub_google_jwks(headers: { "Cache-Control" => "public, max-age=60" })

      verify(google_id_token)
      travel(30.seconds) { verify(google_id_token) }
      travel(61.seconds) { verify(google_id_token) }

      expect(a_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL)).to have_been_made.twice
    end

    it "refetches after an hour when Google sends no max-age" do
      verify(google_id_token)
      travel(61.minutes) { verify(google_id_token) }

      expect(a_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL)).to have_been_made.twice
    end

    it "picks up a rotated key when the key id is unknown" do
      stub_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL).to_return(
        { status: 200, body: google_jwks("kid-1") },
        { status: 200, body: google_jwks("kid-1", "kid-2") }
      )

      verify(google_id_token)
      expect(verify(google_id_token(kid: "kid-2")).sub).to eq("google-sub-1")
      expect(a_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL)).to have_been_made.twice
    end

    it "refetches for an unknown key id at most once a minute" do
      3.times { expect(error_code { google_id_token(kid: "unknown") }).to eq("oauth_token_invalid") }

      expect(a_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL)).to have_been_made.twice
    end
  end

  describe "when Google cannot be reached" do
    before { allow(Rails.logger).to receive(:warn) }

    it "raises ProviderUnavailable on a server error" do
      stub_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL).to_return(status: 500)
      expect { verify(google_id_token) }.to raise_error(Auth::ProviderUnavailable)
    end

    it "raises ProviderUnavailable on a timeout, a network error and an invalid body, logging only the class" do
      stub_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL).to_timeout
      expect { verify(google_id_token) }.to raise_error(Auth::ProviderUnavailable)
      expect(Rails.logger).to have_received(:warn).with({ message: "Google JWKS fetch failed", error: "Net::OpenTimeout" })

      stub_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL).to_raise(SocketError)
      expect { verify(google_id_token) }.to raise_error(Auth::ProviderUnavailable)

      stub_request(:get, GoogleOauthHelpers::GOOGLE_JWKS_URL).to_return(status: 200, body: "<html>")
      expect { verify(google_id_token) }.to raise_error(Auth::ProviderUnavailable)
    end
  end
end
