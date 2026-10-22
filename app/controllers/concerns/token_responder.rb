# Entrega dos tokens ao cliente, em dois modos:
#
# - body (padrão; apps mobile e BFF/servidor Node): refresh_token vem no JSON.
# - cookie (SPA no navegador): envie o header `X-Token-Transport: cookie`.
#   O refresh token vai num cookie httpOnly + SameSite=Strict que o JavaScript
#   não consegue ler (um XSS não rouba a sessão). O header customizado força
#   preflight de CORS, então outros sites não conseguem disparar o refresh (CSRF).
module TokenResponder
  extend ActiveSupport::Concern

  REFRESH_COOKIE = "trita_refresh".freeze
  REFRESH_COOKIE_PATH = "/api/v1/auth".freeze

  private

  def cookie_transport?
    request.headers["X-Token-Transport"].to_s.casecmp?("cookie")
  end

  def render_session(user, tokens, status: :ok)
    tokens = tokens.dup
    if cookie_transport?
      write_refresh_cookie(tokens.delete(:refresh_token))
      tokens[:refresh_token_transport] = "cookie"
    end

    render json: {
      data: {
        user: UserBlueprint.render_as_hash(user),
        tokens: tokens,
        two_factor_setup_required: user.two_factor_setup_required?
      }
    }, status: status
  end

  # Login concluído (após senha e, se houver, 2FA).
  def sign_in_and_render(user, two_factor: false)
    user.reset_failed_logins!
    user.track_sign_in!
    Current.user = user
    AuditLog.record!("auth.login", target: user, actor: user, metadata: { two_factor: two_factor })
    render_session(user, Auth::TokenIssuer.call(user, request: request))
  end

  def refresh_token_from_request
    params[:refresh_token].presence || (cookie_transport? ? cookies[REFRESH_COOKIE].presence : nil)
  end

  def write_refresh_cookie(value)
    cookies[REFRESH_COOKIE] = {
      value: value,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :strict,
      path: REFRESH_COOKIE_PATH,
      expires: Auth::JsonWebToken.refresh_ttl.from_now
    }
  end

  def clear_refresh_cookie
    cookies.delete(REFRESH_COOKIE, path: REFRESH_COOKIE_PATH)
  end
end
