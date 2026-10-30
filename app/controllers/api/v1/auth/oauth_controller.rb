module Api
  module V1
    module Auth
      class OauthController < ApplicationController
        skip_before_action :authenticate_user!

        def google
          claims = ::Auth::Oauth::GoogleVerifier.call(params.require(:id_token))
          user = ::Auth::OauthSignin.call(provider: :google, claims: claims, consents: consents)
          sign_in_or_challenge(user, provider: "google")
        rescue ::Auth::OauthSignin::ConsentRequired => e
          render_error(status: :unprocessable_content, code: "validation_failed", message: "Invalid data", details: consent_details(e.kinds))
        end

        private

        def consents
          Consent::KINDS.keys.index_with { |kind| truthy?(params[:"accept_#{kind}"]) }
        end

        def consent_details(kinds)
          kinds.index_by { |kind| :"accept_#{kind}" }.transform_values do |kind|
            [ { code: "required", message: I18n.t("consents.required", kind: I18n.t("consents.kinds.#{kind}")) } ]
          end
        end
      end
    end
  end
end
