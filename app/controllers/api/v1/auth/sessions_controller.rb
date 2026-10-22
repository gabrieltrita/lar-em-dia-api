module Api
  module V1
    module Auth
      class SessionsController < ApplicationController
        skip_before_action :authenticate_user!, only: :create

        def create
          email = params.require(:email).to_s
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
                                message: "Confirm your email before logging in. You can request a new link.")
          end

          if user.two_factor_enabled?
            user.reset_failed_logins!
            return render json: {
              data: { two_factor_required: true, challenge_token: ::Auth::TwoFactorChallenge.issue(user), expires_in: ::Auth::TwoFactorChallenge::TTL.to_i }
            }
          end

          sign_in_and_render(user)
        end

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
