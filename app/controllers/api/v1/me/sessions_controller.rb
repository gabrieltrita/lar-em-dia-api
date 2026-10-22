module Api
  module V1
    module Me
      class SessionsController < ApplicationController
        def index
          sessions = RefreshToken.sessions_for(current_user).map do |token|
            {
              id: token.family_id,
              current: token.family_id == current_session_id,
              user_agent: token.user_agent,
              ip_address: token.ip_address,
              started_at: token.session_started_at,
              last_activity_at: token.created_at
            }
          end
          render json: { data: sessions }
        end

        def destroy
          raise ActiveRecord::RecordNotFound unless current_user.refresh_tokens.active.exists?(family_id: params[:id])

          current_user.revoke_session!(params[:id])
          AuditLog.record!("session.revoked", target: current_user, metadata: { session_id: params[:id] })
          head :no_content
        end
      end
    end
  end
end
