module Api
  module V1
    module Admin
      class AuditLogsController < BaseController
        def index
          authorize AuditLog
          scope = AuditLog.recent
          scope = scope.where(action: params[:action_name]) if params[:action_name].present?
          scope = scope.where(actor_id: params[:actor_id]) if params[:actor_id].present?
          scope = scope.where(target_id: params[:target_id]) if params[:target_id].present?
          scope = scope.where(created_at: Time.zone.parse(params[:from])..) if params[:from].present?
          scope = scope.where(created_at: ..Time.zone.parse(params[:to]).end_of_day) if params[:to].present?

          pagy, logs = pagy(scope)
          render json: { data: AuditLogBlueprint.render_as_hash(logs), meta: pagination_meta(pagy) }
        end
      end
    end
  end
end
