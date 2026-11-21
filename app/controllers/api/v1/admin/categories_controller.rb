module Api
  module V1
    module Admin
      class CategoriesController < BaseController
        def index
          authorize Category, :manage?
          categories = Category.global.ordered
          categories = categories.where(kind: params[:kind]) if Category.kinds.key?(params[:kind])
          render json: { data: CategoryBlueprint.render_as_hash(categories, view: :admin) }
        end

        def create
          category = Category.new(category_params)
          authorize category

          if category.save
            AuditLog.record!("category.created", target: category, metadata: { key: category.key, kind: category.kind })
            render json: { data: CategoryBlueprint.render_as_hash(category, view: :admin) }, status: :created
          else
            render_validation_errors(category)
          end
        end

        def update
          category = Category.global.find(params[:id])
          authorize category

          if category.update(category_params)
            fields = category.saved_changes.keys - %w[updated_at]
            AuditLog.record!("category.updated", target: category, metadata: { key: category.key, fields: fields }) if fields.any?
            render json: { data: CategoryBlueprint.render_as_hash(category, view: :admin) }
          else
            render_validation_errors(category)
          end
        end

        private

        def category_params
          params.permit(:kind, :key, :name, :position, :default_nature, :active)
        end
      end
    end
  end
end
