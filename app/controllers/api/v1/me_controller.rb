module Api
  module V1
    # Perfil do usuário autenticado.
    class MeController < ApplicationController
      # GET /api/v1/me
      def show
        render json: { data: UserBlueprint.render_as_hash(current_user, view: :self) }
      end

      # PATCH /api/v1/me  { first_name, last_name, phone }
      # E-mail tem fluxo próprio com confirmação: PATCH /me/email.
      def update
        if current_user.update(profile_params)
          AuditLog.record!("user.updated", target: current_user, metadata: { fields: current_user.saved_changes.keys - %w[updated_at] })
          render json: { data: UserBlueprint.render_as_hash(current_user, view: :self) }
        else
          render_validation_errors(current_user)
        end
      end

      # PATCH /api/v1/me/password  { current_password, password, password_confirmation }
      # Encerra todas as sessões (inclusive a atual) e devolve uma sessão nova.
      def update_password
        require_current_password!

        if current_user.update(password: params.require(:password), password_confirmation: params[:password_confirmation])
          render_session(current_user, ::Auth::TokenIssuer.call(current_user, request: request))
        else
          render_validation_errors(current_user)
        end
      end

      # PATCH /api/v1/me/email  { email, current_password }
      # Envia link de confirmação para o novo e-mail e um aviso para o atual.
      # A troca só acontece quando o novo e-mail é confirmado.
      def update_email
        require_current_password!
        new_email = params.require(:email).to_s.strip.downcase

        if new_email == current_user.email
          return render_error(status: :unprocessable_content, code: "validation_failed", message: "Dados inválidos",
                              details: { email: [ "E-mail é igual ao atual" ] })
        end

        current_user.unconfirmed_email = new_email
        return render_validation_errors(current_user) unless current_user.valid?

        # Anti-enumeração: se o e-mail já pertence a outra conta, a resposta é a
        # mesma, mas nenhum link é enviado.
        unless User.exists?(email: new_email)
          current_user.save!
          UserMailer.email_change_confirmation(current_user).deliver_later
          UserMailer.email_change_requested(current_user).deliver_later
          AuditLog.record!("user.email_change_requested", target: current_user)
        end

        render json: { data: { message: "Enviamos um link de confirmação para o novo e-mail." } }, status: :accepted
      end

      # DELETE /api/v1/me  { current_password, code (se 2FA ativo) }
      # LGPD: anonimiza a conta (dados pessoais apagados de forma irreversível).
      def destroy
        require_current_password!
        require_second_factor!

        current_user.anonymize!
        ::Auth::TokenDenylist.add(current_token_payload["jti"], current_token_payload["exp"])
        AuditLog.record!("user.anonymized", target: current_user, metadata: { by: "self" })
        clear_refresh_cookie
        head :no_content
      end

      # GET /api/v1/me/export
      # LGPD (art. 18): portabilidade — todos os dados do titular em JSON.
      def export
        AuditLog.record!("user.data_exported", target: current_user)
        response.headers["Content-Disposition"] = %(attachment; filename="trita-dados-#{Date.current.iso8601}.json")
        render json: UserDataExport.new(current_user).as_json
      end

      private

      def profile_params
        params.permit(:first_name, :last_name, :phone)
      end
    end
  end
end
