# Autenticação via header: Authorization: Bearer <access_token>
module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def current_user
    @current_user
  end

  def current_token_payload
    @current_token_payload
  end

  def current_session_id
    current_token_payload&.dig("sid")
  end

  def authenticate_user!
    token = bearer_token
    raise Auth::Unauthorized, "Token de acesso ausente" if token.blank?

    payload = Auth::JsonWebToken.decode(token, type: "access")
    raise Auth::InvalidToken, "Token revogado" if Auth::TokenDenylist.include?(payload["jti"])
    raise Auth::InvalidToken, "Sessão encerrada" if Auth::TokenDenylist.session_revoked?(payload["sid"])

    user = User.not_anonymized.find_by(id: payload["sub"])
    raise Auth::InvalidToken if user.nil?

    # Tokens emitidos antes de uma troca de senha deixam de valer.
    if user.password_changed_at && payload["iat"].to_i < user.password_changed_at.to_i
      raise Auth::InvalidToken, "Sessão expirada após troca de senha"
    end

    @current_token_payload = payload
    @current_user = user
    Current.user = user
    Sentry.set_user(id: user.id) if Sentry.initialized?
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    scheme, token = header.split(" ", 2)
    token if scheme&.casecmp?("Bearer")
  end

  # Usado pelo Pundit
  def pundit_user
    current_user
  end
end
