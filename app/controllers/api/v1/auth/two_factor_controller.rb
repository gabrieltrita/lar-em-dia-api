module Api
  module V1
    module Auth
      class TwoFactorController < ApplicationController
        skip_before_action :authenticate_user!

        def create
          user, payload = ::Auth::TwoFactorChallenge.verify(params.require(:challenge_token))

          unless user.verify_second_factor(params.require(:code))
            user.register_failed_login!
            AuditLog.record!("auth.two_factor_failed", target: user, actor: nil)
            raise ::Auth::Unauthorized.new("Invalid verification code", code: "invalid_two_factor_code")
          end

          ::Auth::TwoFactorChallenge.consume!(payload)
          sign_in_and_render(user, two_factor: true)
        end
      end
    end
  end
end
