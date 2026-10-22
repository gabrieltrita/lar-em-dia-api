module Api
  module V1
    module Admin
      class BaseController < ApplicationController
        include Paginatable

        before_action :require_admin!

        private

        def require_admin!
          raise Pundit::NotAuthorizedError unless current_user.admin?
          return if current_user.two_factor_enabled?

          render_error(status: :forbidden, code: "two_factor_setup_required",
                       message: "Enable 2FA at /api/v1/me/two_factor to access the admin area.")
        end
      end
    end
  end
end
