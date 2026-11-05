module Api
  module V1
    module Me
      class NotificationSettingsController < ApplicationController
        skip_before_action :authenticate_user!, only: :unsubscribe

        def show
          render json: { data: NotificationSettingsBlueprint.render_as_hash(current_user) }
        end

        def update
          if current_user.update(settings_params)
            record_change(current_user, via: "settings")
            render json: { data: NotificationSettingsBlueprint.render_as_hash(current_user) }
          else
            render_validation_errors(current_user)
          end
        end

        def unsubscribe
          user = User.find_by_token_for(:due_alerts_unsubscribe, params.require(:token).to_s)
          raise ::Auth::InvalidToken.new("Invalid or expired unsubscribe link", code: "invalid_unsubscribe_token") if user.nil? || user.anonymized?

          user.update!(due_alerts_enabled: false)
          record_change(user, via: "unsubscribe_link")
          render json: { data: NotificationSettingsBlueprint.render_as_hash(user) }
        end

        private

        def settings_params
          params.permit(:due_alerts_enabled, :due_alert_days_before)
        end

        def record_change(user, via:)
          fields = user.saved_changes.keys - %w[updated_at]
          AuditLog.record!("user.notification_settings_changed", target: user, actor: user, metadata: { fields: fields, via: via }) if fields.any?
        end
      end
    end
  end
end
