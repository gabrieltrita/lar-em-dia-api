module Auth
  module Oauth
    class AppleRevoker
      BASE_URL = "https://appleid.apple.com".freeze
      TOKEN_URI = URI("#{BASE_URL}/auth/token").freeze
      REVOKE_URI = URI("#{BASE_URL}/auth/revoke").freeze
      SECRET_TTL = 5.minutes
      HTTP_TIMEOUT = 3
      CONFIG_KEYS = %w[APPLE_TEAM_ID APPLE_KEY_ID APPLE_PRIVATE_KEY].freeze
      FAILURES = [ *JwksVerifier::FETCH_ERRORS, OpenSSL::PKey::PKeyError ].freeze

      def self.call(authorization_code:, client_id: nil)
        new(authorization_code, client_id).call
      end

      def initialize(authorization_code, requested_client_id)
        @authorization_code = authorization_code
        @requested_client_id = requested_client_id
      end

      def call
        return false unless configured? && client_id

        secret = client_secret
        token = exchange(secret)
        token.present? && revoke(secret, token)
      rescue *FAILURES => e
        Rails.logger.warn({ message: "Apple token revocation failed", error: e.class.name })
        false
      end

      private

      def configured?
        CONFIG_KEYS.all? { |key| ENV[key].present? }
      end

      def client_id
        allowed = ENV.fetch("APPLE_CLIENT_IDS", "").split(",").map(&:strip).compact_blank
        @requested_client_id.blank? ? allowed.first : allowed.find { |id| id == @requested_client_id }
      end

      def client_secret
        now = Time.current.to_i
        JWT.encode(
          { iss: ENV.fetch("APPLE_TEAM_ID"), iat: now, exp: now + SECRET_TTL.to_i, aud: BASE_URL, sub: client_id },
          OpenSSL::PKey::EC.new(ENV.fetch("APPLE_PRIVATE_KEY").gsub("\\n", "\n")),
          "ES256",
          { kid: ENV.fetch("APPLE_KEY_ID") }
        )
      end

      def exchange(secret)
        response = post(TOKEN_URI, client_id: client_id, client_secret: secret, code: @authorization_code, grant_type: "authorization_code")
        JSON.parse(response.body)["refresh_token"] if response.is_a?(Net::HTTPSuccess)
      end

      def revoke(secret, token)
        post(REVOKE_URI, client_id: client_id, client_secret: secret, token: token, token_type_hint: "refresh_token").is_a?(Net::HTTPSuccess)
      end

      def post(uri, params)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: HTTP_TIMEOUT, read_timeout: HTTP_TIMEOUT) do |http|
          http.post(uri.path, URI.encode_www_form(params), "Content-Type" => "application/x-www-form-urlencoded")
        end
      end
    end
  end
end
