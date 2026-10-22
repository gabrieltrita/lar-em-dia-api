module Api
  module V1
    module Admin
      # Toda rota em /api/v1/admin exige role admin COM 2FA ativo.
      class BaseController < ApplicationController
        include Paginatable

        before_action :require_admin!

        private

        def require_admin!
          raise Pundit::NotAuthorizedError unless current_user.admin?
          return if current_user.two_factor_enabled?

          render_error(status: :forbidden, code: "two_factor_setup_required",
                       message: "Ative o 2FA em /api/v1/me/two_factor para acessar a área administrativa.")
        end
      end
    end
  end
end
