module Auth
  # Senha atual / código 2FA incorreto em ação sensível (vira HTTP 422,
  # não 401, para o front não tentar refresh e deslogar o usuário).
  class ReauthenticationFailed < StandardError; end
end
