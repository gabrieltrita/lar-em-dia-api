module Api
  module V1
    module Auth
      # POST /api/v1/auth/register
      #
      # Anti-enumeração: a resposta é SEMPRE a mesma (202) quando os dados são
      # válidos, exista ou não uma conta com o e-mail. O dono do e-mail é quem
      # recebe a informação, por e-mail:
      # - conta nova: link de confirmação
      # - conta existente não confirmada: novo link de confirmação
      # - conta existente confirmada: aviso de tentativa de cadastro
      class RegistrationsController < ApplicationController
        skip_before_action :authenticate_user!

        def create
          user = User.new(registration_params)
          user.valid?

          details = user.errors.reject { |e| e.attribute == :email && e.type == :taken }
                        .group_by(&:attribute).transform_values { |errs| errs.map(&:full_message) }
          Consent.required_kinds.each do |kind|
            details[:"accept_#{kind}"] = [ I18n.t("consents.required", kind: I18n.t("consents.kinds.#{kind}")) ] unless truthy?(params[:"accept_#{kind}"])
          end

          if details.any?
            return render_error(status: :unprocessable_content, code: "validation_failed", message: "Dados inválidos", details: details)
          end

          existing = User.find_by(email: user.email)
          existing ? notify_existing(existing) : create_account(user)

          render json: { data: { message: "Cadastro recebido! Enviamos um e-mail para concluir. Verifique sua caixa de entrada." } }, status: :accepted
        end

        private

        def create_account(user)
          User.transaction do
            user.save!
            Consent.required_kinds.each { |kind| Consent.record!(user, kind, true) }
            Consent.record!(user, "marketing", truthy?(params[:accept_marketing]))
          end
          AuditLog.record!("user.registered", target: user, actor: user)
          UserMailer.confirmation_instructions(user).deliver_later
        rescue ActiveRecord::RecordNotUnique
          # Corrida: outro cadastro com o mesmo e-mail entrou no meio.
          existing = User.find_by(email: user.email)
          notify_existing(existing) if existing
        end

        def notify_existing(user)
          if user.confirmed?
            UserMailer.registration_attempt(user).deliver_later
          else
            UserMailer.confirmation_instructions(user).deliver_later
          end
        end

        def registration_params
          params.permit(:email, :password, :password_confirmation, :first_name, :last_name, :phone)
        end
      end
    end
  end
end
