module Auth
  # Troca um refresh token válido por um novo par de tokens (rotação).
  # Se um token já revogado for reutilizado, assume vazamento e derruba
  # todas as sessões do usuário.
  class RefreshTokenRotator
    def self.call(raw_token, request: nil)
      new(raw_token, request).call
    end

    def initialize(raw_token, request)
      @raw_token = raw_token
      @request = request
    end

    def call
      record = RefreshToken.find_by_raw_token(@raw_token)
      raise InvalidToken if record.nil?

      user = record.user

      if record.revoked?
        user.revoke_all_sessions!
        AuditLog.record!("auth.refresh_reuse_detected", target: user, actor: nil)
        raise InvalidToken, "Refresh token reutilizado. Todas as sessões foram encerradas."
      end

      raise InvalidToken if record.expired? || user.anonymized?
      # Defesa extra: nenhum token emitido antes da última troca de senha vale.
      raise InvalidToken if user.password_changed_at && record.created_at < user.password_changed_at

      RefreshToken.transaction do
        # Lock evita que duas requisições simultâneas usem o mesmo token.
        record.lock!
        raise InvalidToken if record.revoked?

        record.revoke!
        tokens = TokenIssuer.call(user, request: @request, family_id: record.family_id, session_started_at: record.session_started_at)
        [ user, tokens ]
      end
    end
  end
end
