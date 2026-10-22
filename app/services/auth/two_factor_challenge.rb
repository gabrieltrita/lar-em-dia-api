module Auth
  # Token de curta duração entregue no login quando o usuário tem 2FA.
  # Só serve para o passo POST /auth/two_factor e é de uso único.
  class TwoFactorChallenge
    TTL = 5.minutes
    TYPE = "2fa_challenge".freeze

    class << self
      def issue(user)
        JsonWebToken.encode({ sub: user.id, type: TYPE }, expires_at: TTL.from_now)
      end

      def verify(token)
        payload = JsonWebToken.decode(token.to_s, type: TYPE)
        raise InvalidToken, "Desafio 2FA expirado. Faça login novamente." if TokenDenylist.include?(payload["jti"])

        user = User.not_anonymized.find_by(id: payload["sub"])
        raise InvalidToken if user.nil? || user.access_locked?

        [ user, payload ]
      end

      def consume!(payload)
        TokenDenylist.add(payload["jti"], payload["exp"])
      end
    end
  end
end
