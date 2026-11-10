module Api
  module V1
    module Auth
      class UnlocksController < ApplicationController
        skip_before_action :authenticate_user!

        def create
          user = User.find_by_token_for(:unlock, params.require(:token).to_s)
          raise ::Auth::InvalidToken.new("Invalid or expired unlock link", code: "invalid_unlock_token") unless user&.unlockable_by_email?

          user.unlock!
          AuditLog.record!("auth.unlocked_by_email", target: user, actor: user)
          sign_in_or_challenge(user)
        end
      end
    end
  end
end
