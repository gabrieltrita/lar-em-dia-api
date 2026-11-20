module Api
  module V1
    class AllocationPlansController < ApplicationController
      include ProjectionPeriod

      def show
        authorize :allocation_plan
        month = parse_projection_month(params[:month])
        return render_error(status: :bad_request, code: "invalid_month", message: "month must be a month (YYYY-MM)") unless month

        render json: { data: AllocationPlan.new(user: current_user, month: month).to_h }
      end
    end
  end
end
