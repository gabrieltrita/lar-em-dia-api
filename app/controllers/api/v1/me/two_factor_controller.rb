module Api
  module V1
    module Me
      class TwoFactorController < ApplicationController
        def show
          render json: { data: { enabled: current_user.two_factor_enabled?, required: current_user.admin?, backup_codes_remaining: current_user.backup_codes_remaining } }
        end

        def setup
          require_current_password!
          return already_enabled if current_user.two_factor_enabled?

          current_user.generate_otp_secret!
          render json: { data: { secret: current_user.otp_secret, provisioning_uri: current_user.otp_provisioning_uri } }
        end

        def enable
          codes = current_user.enable_two_factor!(params.require(:code))
          raise ::Auth::ReauthenticationFailed.new("Invalid code. Check the device clock and try again.", code: "invalid_two_factor_code") if codes.nil?

          current_user.revoke_all_sessions!(except_family: current_session_id)
          AuditLog.record!("two_factor.enabled", target: current_user)
          render json: { data: { enabled: true, backup_codes: codes } }
        end

        def destroy
          if current_user.admin?
            return render_error(status: :forbidden, code: "two_factor_required", message: "Admins cannot disable 2FA.")
          end
          return render_error(status: :unprocessable_content, code: "two_factor_not_enabled", message: "2FA is not enabled") unless current_user.two_factor_enabled?

          require_current_password!
          require_second_factor!

          current_user.disable_two_factor!
          AuditLog.record!("two_factor.disabled", target: current_user)
          UserMailer.two_factor_disabled(current_user).deliver_later
          head :no_content
        end

        def backup_codes
          return render_error(status: :unprocessable_content, code: "two_factor_not_enabled", message: "2FA is not enabled") unless current_user.two_factor_enabled?

          require_current_password!
          require_second_factor!

          codes = current_user.regenerate_backup_codes!
          AuditLog.record!("two_factor.backup_codes_regenerated", target: current_user)
          render json: { data: { backup_codes: codes } }
        end

        private

        def already_enabled
          render_error(status: :unprocessable_content, code: "two_factor_already_enabled", message: "2FA is already enabled")
        end
      end
    end
  end
end
