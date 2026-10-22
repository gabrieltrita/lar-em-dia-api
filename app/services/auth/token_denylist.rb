module Auth
  class TokenDenylist
    TOKEN_PREFIX = "auth:jwt:denylist".freeze
    SESSION_PREFIX = "auth:session:revoked".freeze

    class << self
      def add(jti, exp)
        ttl = exp.to_i - Time.current.to_i
        return if ttl <= 0

        Rails.cache.write("#{TOKEN_PREFIX}:#{jti}", true, expires_in: ttl.seconds)
      end

      def include?(jti)
        Rails.cache.exist?("#{TOKEN_PREFIX}:#{jti}")
      end

      def revoke_session(sid)
        Rails.cache.write("#{SESSION_PREFIX}:#{sid}", true, expires_in: JsonWebToken.access_ttl + 1.minute)
      end

      def session_revoked?(sid)
        sid.present? && Rails.cache.exist?("#{SESSION_PREFIX}:#{sid}")
      end
    end
  end
end
