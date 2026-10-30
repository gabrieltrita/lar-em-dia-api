module Auth
  module Oauth
    class GoogleVerifier
      JWKS_URI = URI("https://www.googleapis.com/oauth2/v3/certs").freeze
      ISSUERS = %w[https://accounts.google.com accounts.google.com].freeze
      ALGORITHM = "RS256".freeze
      JWKS_CACHE_KEY = "oauth/google/jwks".freeze
      REFRESH_COOLDOWN_KEY = "oauth/google/jwks_refresh".freeze
      DEFAULT_JWKS_TTL = 1.hour
      REFRESH_COOLDOWN = 1.minute
      HTTP_TIMEOUT = 3
      FETCH_ERRORS = [ SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, JSON::ParserError ].freeze

      Claims = Data.define(:sub, :email, :given_name, :family_name)

      def self.call(id_token)
        new.call(id_token)
      end

      def call(id_token)
        payload, = JWT.decode(
          id_token.to_s, nil, true,
          algorithms: [ ALGORITHM ],
          jwks: method(:jwks),
          iss: ISSUERS, verify_iss: true,
          aud: client_ids, verify_aud: true,
          required_claims: %w[exp iss aud sub]
        )

        unless payload["email"].present? && ActiveModel::Type::Boolean.new.cast(payload["email_verified"]) == true
          raise Unauthorized.new("The Google email is not verified", code: "oauth_email_unverified")
        end

        Claims.new(sub: payload["sub"], email: payload["email"], given_name: payload["given_name"], family_name: payload["family_name"])
      rescue JWT::DecodeError
        raise Unauthorized.new("Invalid Google token", code: "oauth_token_invalid")
      end

      private

      def client_ids
        ENV.fetch("GOOGLE_CLIENT_IDS", "").split(",").map(&:strip).compact_blank
      end

      def jwks(options)
        if options[:invalidate] && Rails.cache.write(REFRESH_COOLDOWN_KEY, true, expires_in: REFRESH_COOLDOWN, unless_exist: true)
          return fetch_jwks
        end

        Rails.cache.read(JWKS_CACHE_KEY) || fetch_jwks
      end

      def fetch_jwks
        response = Net::HTTP.start(JWKS_URI.host, JWKS_URI.port, use_ssl: true, open_timeout: HTTP_TIMEOUT, read_timeout: HTTP_TIMEOUT) do |http|
          http.get(JWKS_URI.request_uri)
        end
        raise ProviderUnavailable unless response.is_a?(Net::HTTPSuccess)

        keys = JSON.parse(response.body)
        Rails.cache.write(JWKS_CACHE_KEY, keys, expires_in: jwks_ttl(response))
        keys
      rescue *FETCH_ERRORS => e
        Rails.logger.warn({ message: "Google JWKS fetch failed", error: e.class.name })
        raise ProviderUnavailable
      end

      def jwks_ttl(response)
        max_age = response["cache-control"].to_s[/max-age=(\d+)/, 1]
        max_age ? max_age.to_i.seconds : DEFAULT_JWKS_TTL
      end
    end
  end
end
