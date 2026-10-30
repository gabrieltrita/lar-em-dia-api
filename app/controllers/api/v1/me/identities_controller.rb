module Api
  module V1
    module Me
      class IdentitiesController < ApplicationController
        def index
          render json: { data: IdentityBlueprint.render_as_hash(current_user.identities.order(:created_at)) }
        end

        def destroy
          identity = current_user.identities.find(params[:id])
          require_reauthentication!

          if current_user.login_methods_count <= 1
            return render_error(status: :unprocessable_content, code: "last_login_method",
                                message: "You cannot remove your only way to log in.")
          end

          identity.destroy!
          AuditLog.record!("identity.unlinked", target: current_user, metadata: { provider: identity.provider })
          head :no_content
        end
      end
    end
  end
end
