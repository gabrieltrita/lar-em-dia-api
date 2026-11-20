module Api
  module V1
    class AllocationsController < ApplicationController
      include ProjectionPeriod

      def create
        recorder = AllocationRecorder.new(current_user)
        authorize recorder.record
        month = parse_projection_month(params.require(:month))
        return render_error(status: :bad_request, code: "invalid_month", message: "month must be a month (YYYY-MM)") unless month
        return render_validation_errors(recorder.record) unless recorder.create(target_id: params[:target_id], month: month, amount_cents: params[:amount_cents])

        render json: { data: AllocationBlueprint.render_as_hash(recorder.record) }, status: :created
      end

      def destroy
        allocation = policy_scope(Allocation).find(params[:id])
        authorize allocation
        recorder = AllocationRecorder.new(current_user, allocation)
        return render json: { data: { deleted_id: allocation.id } } if recorder.destroy

        render_error(status: :unprocessable_content, code: recorder.error_code,
          message: "Undoing this allocation would leave a later reserve withdrawal without enough money")
      end
    end
  end
end
