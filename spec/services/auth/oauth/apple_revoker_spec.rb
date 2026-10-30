require "rails_helper"

RSpec.describe Auth::Oauth::AppleRevoker do
  include_context "with apple revocation"

  def revoke(code: "authorization-code", client_id: nil)
    described_class.call(authorization_code: code, client_id: client_id)
  end

  def form_of(url)
    body = nil
    expect(a_request(:post, url).with { |request| body = URI.decode_www_form(request.body).to_h }).to have_been_made
    body
  end

  before { allow(Rails.logger).to receive(:warn) }

  it "exchanges the code and revokes the refresh token" do
    expect(revoke).to be(true)

    exchange = form_of(apple_token_url)
    expect(exchange).to include("grant_type" => "authorization_code", "code" => "authorization-code", "client_id" => AppleOauthHelpers::APPLE_CLIENT_ID)
    expect(form_of(apple_revoke_url)).to include("token" => "apple-refresh-token", "token_type_hint" => "refresh_token", "client_id" => AppleOauthHelpers::APPLE_CLIENT_ID)
  end

  it "signs a short-lived ES256 client secret with the team, key and client" do
    revoke

    secret = form_of(apple_token_url)["client_secret"]
    payload, header = JWT.decode(secret, OpenSSL::PKey::EC.new(apple_signing_key.public_to_der), true, algorithm: "ES256")

    expect(header["kid"]).to eq("KEY1234567")
    expect(payload).to include("iss" => "TEAM123456", "aud" => "https://appleid.apple.com", "sub" => AppleOauthHelpers::APPLE_CLIENT_ID)
    expect(payload["exp"] - payload["iat"]).to eq(5.minutes.to_i)
  end

  it "uses the requested client id when it is allowed and refuses one that is not" do
    expect(revoke(client_id: "com.example.web")).to be(true)
    expect(form_of(apple_token_url)["client_id"]).to eq("com.example.web")

    WebMock.reset_executed_requests!
    expect(revoke(client_id: "com.someone.else")).to be(false)
    expect(a_request(:post, apple_token_url)).not_to have_been_made
  end

  it "does nothing when the Sign in with Apple key is not configured" do
    ENV.delete("APPLE_PRIVATE_KEY")

    expect(revoke).to be(false)
    expect(a_request(:post, apple_token_url)).not_to have_been_made
  end

  it "fails when Apple rejects the code" do
    stub_request(:post, apple_token_url).to_return(status: 400, body: { error: "invalid_grant" }.to_json)

    expect(revoke).to be(false)
    expect(a_request(:post, apple_revoke_url)).not_to have_been_made
  end

  it "fails when Apple returns no refresh token" do
    stub_request(:post, apple_token_url).to_return(status: 200, body: {}.to_json)

    expect(revoke).to be(false)
    expect(a_request(:post, apple_revoke_url)).not_to have_been_made
  end

  it "fails when Apple rejects the revocation" do
    stub_request(:post, apple_revoke_url).to_return(status: 400)
    expect(revoke).to be(false)
  end

  it "fails quietly on a timeout, an invalid key or an invalid response, logging only the error class" do
    stub_request(:post, apple_token_url).to_timeout
    expect(revoke(code: "secret-code")).to be(false)
    expect(Rails.logger).to have_received(:warn).with({ message: "Apple token revocation failed", error: "Net::OpenTimeout" })

    stub_request(:post, apple_token_url).to_return(status: 200, body: "<html>")
    expect(revoke).to be(false)

    ENV["APPLE_PRIVATE_KEY"] = "not-a-key"
    expect(revoke).to be(false)
    expect(Rails.logger).to have_received(:warn).exactly(3).times
    expect(Rails.logger).not_to have_received(:warn).with(a_hash_including(message: a_string_matching(/secret-code|not-a-key/)))
  end
end
