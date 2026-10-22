module Api
  module V1
    module Auth
      class ConfirmationsController < ApplicationController
        skip_before_action :authenticate_user!

        def create
          user = User.find_by_token_for(:email_confirmation, params.require(:token))
          raise ::Auth::InvalidToken.new("Invalid or expired confirmation link", code: "invalid_confirmation_token") if user.nil? || user.anonymized?

          user.confirm!
          AuditLog.record!("user.confirmed", target: user, actor: user)
          UserMailer.welcome(user).deliver_later
          sign_in_and_render(user)
        end

        def resend
          user = User.not_anonymized.find_by(email: params.require(:email).to_s)
          UserMailer.confirmation_instructions(user).deliver_later if user && !user.confirmed?

          render json: { data: { message: "If there is a pending account for this email, a new link is on its way." } }, status: :accepted
        end

        def email_change
          user = User.find_by_token_for(:email_change, params.require(:token))
          raise ::Auth::InvalidToken.new("Invalid or expired email change link", code: "invalid_email_change_token") if user.nil? || user.anonymized?

          user.confirm_email_change!
          render json: { data: { message: "Email changed successfully.", user: UserBlueprint.render_as_hash(user) } }
        end
      end
    end
  end
end
