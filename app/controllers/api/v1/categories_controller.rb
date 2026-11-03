module Api
  module V1
    class CategoriesController < ApplicationController
      def index
        authorize Category
        categories = policy_scope(Category).ordered
        categories = categories.where(kind: params[:kind]) if Category.kinds.key?(params[:kind])
        render json: { data: CategoryBlueprint.render_as_hash(categories) }
      end
    end
  end
end
