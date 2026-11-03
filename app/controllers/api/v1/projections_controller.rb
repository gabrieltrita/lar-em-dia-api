module Api
  module V1
    class ProjectionsController < ApplicationController
      MONTH_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

      def show
        authorize Projection
        return render_error(status: :bad_request, code: "invalid_month", message: "from must be a month (YYYY-MM)") unless from

        return render_error(status: :bad_request, code: "invalid_months", message: "months must be an integer from 1 to 24") unless months

        projection = Projection.new(user: current_user, from: from, months: months)
        render json: { data: { anchor: anchor_json(projection.anchor), months: projection.months } }
      end

      private

      def from
        return Date.current.beginning_of_month if params[:from].blank?

        Date.strptime(params[:from], "%Y-%m") if MONTH_FORMAT.match?(params[:from])
      end

      def months
        return Projection::DEFAULT_MONTHS if params[:months].blank?

        value = Integer(params[:months].to_s, 10, exception: false)
        value if Projection::MONTHS_RANGE.cover?(value)
      end

      def anchor_json(balance)
        balance && { amount_cents: balance.amount_cents, as_of: balance.as_of.iso8601 }
      end
    end
  end
end
