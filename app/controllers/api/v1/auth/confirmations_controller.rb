module Api
  module V1
    module Auth
      class ConfirmationsController < ApplicationController
        skip_before_action :authenticate_user!

        # POST /api/v1/auth/confirm  { token }
        # Confirma o e-mail e já devolve a sessão (login automático).
        def create
          user = User.find_by_token_for(:email_confirmation, params.require(:token))
          raise ::Auth::InvalidToken, "Link de confirmação inválido ou expirado" if user.nil? || user.anonymized?

          user.confirm!
          AuditLog.record!("user.confirmed", target: user, actor: user)
          UserMailer.welcome(user).deliver_later
          sign_in_and_render(user)
        end

        # POST /api/v1/auth/confirm/resend  { email }   (sempre 202)
        def resend
          user = User.not_anonymized.find_by(email: params.require(:email).to_s)
          UserMailer.confirmation_instructions(user).deliver_later if user && !user.confirmed?

          render json: { data: { message: "Se houver uma conta pendente para este e-mail, enviaremos um novo link." } }, status: :accepted
        end

        # POST /api/v1/auth/email/confirm  { token }
        # Conclui a troca de e-mail iniciada em PATCH /me/email.
        def email_change
          user = User.find_by_token_for(:email_change, params.require(:token))
          raise ::Auth::InvalidToken, "Link inválido ou expirado" if user.nil? || user.anonymized?

          user.confirm_email_change!
          render json: { data: { message: "E-mail alterado com sucesso.", user: UserBlueprint.render_as_hash(user) } }
        end
      end
    end
  end
end
