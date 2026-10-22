module Api
  module V1
    module Auth
      # POST /api/v1/auth/refresh
      # Body { refresh_token } ou, no modo cookie, header `X-Token-Transport: cookie`.
      class TokensController < ApplicationController
        skip_before_action :authenticate_user!

        def create
          raw = refresh_token_from_request
          raise ActionController::ParameterMissing, :refresh_token if raw.blank?

          user, tokens = ::Auth::RefreshTokenRotator.call(raw, request: request)
          render_session(user, tokens)
        rescue ::Auth::Unauthorized
          clear_refresh_cookie
          raise
        end
      end
    end
  end
end
