module Api
  module V1
    class ReservesController < ApplicationController
      GOAL_FIELDS = { goal_months: :reserve_goal_months, goal_cents: :reserve_goal_cents }.freeze

      before_action { authorize :reserve }

      def show
        render json: { data: ReserveSummary.new(current_user).to_h }
      end

      def update
        unless current_user.update(goal_params)
          details = validation_details(current_user.errors).transform_keys(GOAL_FIELDS.invert)
          return render_error(status: :unprocessable_content, code: "validation_failed", message: "Invalid data", details: details)
        end

        render json: { data: ReserveSummary.new(current_user).to_h }
      end

      def projection
        months = params[:months].blank? ? ReserveProjection::DEFAULT_MONTHS : Integer(params[:months].to_s, 10, exception: false)
        unless ReserveProjection::MONTHS_RANGE.cover?(months)
          return render_error(status: :bad_request, code: "invalid_months", message: "months must be an integer from 1 to 60")
        end

        reserve = ReserveProjection.new(current_user, months: months)
        render json: { data: { months: reserve.months, assumptions: reserve.assumptions } }
      end

      private

      def goal_params
        params.permit(*GOAL_FIELDS.keys).to_h.transform_keys { |field| GOAL_FIELDS.fetch(field.to_sym) }
      end
    end
  end
end
