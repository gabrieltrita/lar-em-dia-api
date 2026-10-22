module Api
  module V1
    module Auth
      class RegistrationsController < ApplicationController
        skip_before_action :authenticate_user!

        def create
          user = User.new(registration_params)
          user.valid?

          details = validation_details(user.errors.reject { |e| e.attribute == :email && e.type == :taken })
          Consent.required_kinds.each do |kind|
            next if truthy?(params[:"accept_#{kind}"])

            details[:"accept_#{kind}"] = [ { code: "required", message: I18n.t("consents.required", kind: I18n.t("consents.kinds.#{kind}")) } ]
          end

          if details.any?
            return render_error(status: :unprocessable_content, code: "validation_failed", message: "Invalid data", details: details)
          end

          existing = User.find_by(email: user.email)
          existing ? notify_existing(existing) : create_account(user)

          render json: { data: { message: "Registration received. Check your inbox to finish signing up." } }, status: :accepted
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
