module Api
  module V1
    # GET /api/v1/roles
    class RolesController < ApplicationController
      def index
        render json: { data: User.roles_list.map { |role| { name: role, label: I18n.t("roles.#{role}") } } }
      end
    end
  end
end
