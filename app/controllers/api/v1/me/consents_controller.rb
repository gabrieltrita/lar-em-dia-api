module Api
  module V1
    module Me
      class ConsentsController < ApplicationController
        def index
          render json: { data: Consent.status_for(current_user) }
        end

        def create
          kind = params.require(:kind).to_s
          raise ActiveRecord::RecordNotFound unless Consent::KINDS.key?(kind)

          granted = truthy?(params.require(:granted))
          if !granted && Consent.required_kinds.include?(kind)
            return render_error(status: :unprocessable_content, code: "consent_required",
                                message: "This consent is required to use the service. To close the account use DELETE /me.")
          end

          Consent.record!(current_user, kind, granted)
          AuditLog.record!("user.consent_changed", target: current_user, metadata: { kind: kind, granted: granted })
          render json: { data: Consent.status_for(current_user) }, status: :created
        end
      end
    end
  end
end
