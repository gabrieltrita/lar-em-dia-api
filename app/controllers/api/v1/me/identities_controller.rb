module Api
  module V1
    module Me
      class IdentitiesController < ApplicationController
        def index
          render json: { data: IdentityBlueprint.render_as_hash(current_user.identities.order(:created_at)) }
        end

        def create
          provider = provider_param
          unless ::Auth::Oauth::Providers.supported?(provider)
            return render_error(status: :unprocessable_content, code: "validation_failed", message: "Invalid data",
                                details: { provider: [ { code: "inclusion", message: "Provider is not supported" } ] })
          end

          require_reauthentication!(provider_token: false)
          claims = ::Auth::Oauth::Providers.verify(provider, params.require(:id_token))
          return identity_already_linked if Identity.exists?(provider: provider, provider_uid: claims.sub) || current_user.identities.exists?(provider: provider)

          identity = current_user.identities.create!(provider: provider, provider_uid: claims.sub, email_at_link: claims.email)
          AuditLog.record!("identity.linked", target: current_user, metadata: { provider: provider })
          UserMailer.identity_linked(identity).deliver_later
          render json: { data: IdentityBlueprint.render_as_hash(identity) }, status: :created
        rescue ActiveRecord::RecordNotUnique
          identity_already_linked
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

        private

        def identity_already_linked
          render_error(status: :unprocessable_content, code: "identity_already_linked", message: "This provider account is already linked.")
        end
      end
    end
  end
end
