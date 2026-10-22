module Api
  module V1
    module Auth
      class SessionsController < ApplicationController
        skip_before_action :authenticate_user!, only: :create

        # POST /api/v1/auth/login  { email, password }
        #
        # Respostas:
        # - 200 { user, tokens }                               login concluído
        # - 200 { two_factor_required: true, challenge_token } falta o código 2FA
        # - 401 credenciais inválidas (inclusive conta bloqueada: mesma mensagem)
        # - 403 email_not_confirmed (só depois de acertar a senha)
        def create
          email = params.require(:email).to_s
          # authenticate_by evita timing attack mesmo quando o usuário não existe.
          user = User.authenticate_by(email: email, password: params.require(:password).to_s)
          candidate = user || User.find_by(email: email)

          if candidate&.access_locked?
            AuditLog.record!("auth.login_blocked", target: candidate, actor: nil)
            raise ::Auth::InvalidCredentials
          end

          if user.nil?
            candidate&.register_failed_login!
            AuditLog.record!("auth.login_failed", target: candidate, actor: nil)
            raise ::Auth::InvalidCredentials
          end

          unless user.confirmed?
            return render_error(status: :forbidden, code: "email_not_confirmed",
                                message: "Confirme seu e-mail antes de entrar. Você pode pedir um novo link.")
          end

          if user.two_factor_enabled?
            user.reset_failed_logins!
            return render json: {
              data: { two_factor_required: true, challenge_token: ::Auth::TwoFactorChallenge.issue(user), expires_in: ::Auth::TwoFactorChallenge::TTL.to_i }
            }
          end

          sign_in_and_render(user)
        end

        # DELETE /api/v1/auth/logout   body opcional: { all_devices: true }
        # Encerra a sessão atual (ou todas) na hora, inclusive o access token.
        def destroy
          ::Auth::TokenDenylist.add(current_token_payload["jti"], current_token_payload["exp"])

          if truthy?(params[:all_devices])
            current_user.revoke_all_sessions!
          elsif current_session_id
            current_user.revoke_session!(current_session_id)
          end

          clear_refresh_cookie
          AuditLog.record!("auth.logout", target: current_user, metadata: { all_devices: truthy?(params[:all_devices]) })
          head :no_content
        end
      end
    end
  end
end
