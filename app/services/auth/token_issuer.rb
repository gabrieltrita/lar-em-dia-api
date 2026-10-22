module Auth
  # Emite o par access token (JWT, curta duração) + refresh token (opaco, longa duração).
  # family_id identifica a sessão/dispositivo e se mantém nas rotações.
  class TokenIssuer
    def self.call(user, request: nil, family_id: nil, session_started_at: nil)
      new(user, request, family_id, session_started_at).call
    end

    def initialize(user, request, family_id, session_started_at)
      @user = user
      @request = request
      @family_id = family_id || SecureRandom.uuid
      @session_started_at = session_started_at || Time.current
    end

    def call
      access_expires_at = JsonWebToken.access_ttl.from_now
      access_token = JsonWebToken.encode(
        { sub: @user.id, sid: @family_id, type: "access" },
        expires_at: access_expires_at
      )

      raw_refresh = SecureRandom.urlsafe_base64(64)
      @user.refresh_tokens.create!(
        token_digest: RefreshToken.digest(raw_refresh),
        family_id: @family_id,
        session_started_at: @session_started_at,
        expires_at: JsonWebToken.refresh_ttl.from_now,
        user_agent: @request&.user_agent&.truncate(500),
        ip_address: @request&.remote_ip
      )

      {
        token_type: "Bearer",
        access_token: access_token,
        expires_in: JsonWebToken.access_ttl.to_i,
        expires_at: access_expires_at.iso8601,
        refresh_token: raw_refresh
      }
    end
  end
end
