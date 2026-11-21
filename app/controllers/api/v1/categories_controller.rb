module Api
  module V1
    class CategoriesController < ApplicationController
      CREATE_FIELDS = %i[kind name default_nature].freeze
      UPDATE_FIELDS = %i[name default_nature].freeze

      before_action :set_category, only: %i[update destroy]

      def index
        authorize Category
        categories = policy_scope(Category).ordered
        categories = categories.where(kind: params[:kind]) if Category.kinds.key?(params[:kind])
        render json: { data: CategoryBlueprint.render_as_hash(categories) }
      end

      def create
        category = current_user.categories.new(params.permit(*CREATE_FIELDS))
        authorize category, :create_own?
        return render_validation_errors(category) unless category.save

        render json: { data: CategoryBlueprint.render_as_hash(category) }, status: :created
      end

      def update
        return render_validation_errors(@category) unless @category.update(params.permit(*UPDATE_FIELDS))

        render json: { data: CategoryBlueprint.render_as_hash(@category) }
      end

      def destroy
        return render_category_in_use unless @category.destroy

        render json: { data: { deleted_id: @category.id } }
      end

      private

      def set_category
        @category = current_user.categories.find(params[:id])
        authorize @category, :manage_own?
      end

      def render_category_in_use
        render_error(status: :unprocessable_content, code: "category_in_use", message: "Category has entries")
      end
    end
  end
end
