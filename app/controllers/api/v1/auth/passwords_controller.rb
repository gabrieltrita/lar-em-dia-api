module Api
  module V1
    module Auth
      class PasswordsController < ApplicationController
        skip_before_action :authenticate_user!

        # POST /api/v1/auth/password/forgot  { email }
        # Sempre responde 202 para não revelar se o e-mail existe.
        def forgot
          user = User.not_anonymized.find_by(email: params.require(:email).to_s)
          if user
            # O token é gerado dentro do mailer: nunca passa por Redis/logs do Sidekiq.
            UserMailer.password_reset(user).deliver_later
            AuditLog.record!("user.password_reset_requested", target: user, actor: nil)
          end

          render json: { data: { message: "Se o e-mail estiver cadastrado, você receberá as instruções em instantes." } }, status: :accepted
        end

        # POST /api/v1/auth/password/reset  { token, password, password_confirmation }
        # Encerra todas as sessões, desbloqueia a conta e confirma o e-mail
        # (quem recebeu o link prova ser dono dele).
        def reset
          user = User.find_by_token_for(:password_reset, params.require(:token))
          raise ::Auth::InvalidToken, "Link de redefinição inválido ou expirado" if user.nil? || user.anonymized?

          user.assign_attributes(password: params.require(:password), password_confirmation: params[:password_confirmation])
          user.confirmed_at ||= Time.current

          if user.save
            AuditLog.record!("user.password_reset", target: user, actor: user)
            render json: { data: { message: "Senha redefinida com sucesso. Faça login novamente." } }
          else
            render_validation_errors(user)
          end
        end
      end
    end
  end
end
