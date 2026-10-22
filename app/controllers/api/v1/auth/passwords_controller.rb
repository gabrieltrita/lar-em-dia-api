module Api
  module V1
    module Auth
      class PasswordsController < ApplicationController
        skip_before_action :authenticate_user!

        def forgot
          user = User.not_anonymized.find_by(email: params.require(:email).to_s)
          if user
            UserMailer.password_reset(user).deliver_later
            AuditLog.record!("user.password_reset_requested", target: user, actor: nil)
          end

          render json: { data: { message: "If the email is registered, you will receive instructions shortly." } }, status: :accepted
        end

        def reset
          user = User.find_by_token_for(:password_reset, params.require(:token))
          raise ::Auth::InvalidToken.new("Invalid or expired password reset link", code: "invalid_reset_token") if user.nil? || user.anonymized?

          user.assign_attributes(password: params.require(:password), password_confirmation: params[:password_confirmation])
          user.confirmed_at ||= Time.current

          if user.save
            AuditLog.record!("user.password_reset", target: user, actor: user)
            render json: { data: { message: "Password reset successfully. Please log in again." } }
          else
            render_validation_errors(user)
          end
        end
      end
    end
  end
end
