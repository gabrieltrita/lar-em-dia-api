module Api
  module V1
    class AllocationTargetsController < ApplicationController
      FIELDS = %i[name mode amount_cents percent_bps reserve_account_id position].freeze

      before_action :set_target, only: %i[update destroy]

      def index
        authorize AllocationTarget
        render json: { data: AllocationTargetBlueprint.render_as_hash(policy_scope(AllocationTarget).ordered) }
      end

      def create
        target = current_user.allocation_targets.new(target_params)
        authorize target
        return render_validation_errors(target) unless target.save

        render json: { data: AllocationTargetBlueprint.render_as_hash(target) }, status: :created
      end

      def update
        return render_validation_errors(@target) unless @target.update(target_params)

        render json: { data: AllocationTargetBlueprint.render_as_hash(@target) }
      end

      def destroy
        @target.destroy!
        render json: { data: { deleted_id: @target.id } }
      end

      private

      def set_target
        @target = policy_scope(AllocationTarget).find(params[:id])
        authorize @target
      end

      def target_params
        params.permit(*FIELDS)
      end
    end
  end
end
