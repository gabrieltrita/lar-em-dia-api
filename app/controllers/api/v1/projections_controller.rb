module Api
  module V1
    class ProjectionsController < ApplicationController
      MONTH_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

      SIMULATION_ENTRY_FIELDS = %i[category_id nature description amount_cents due_on entries_count direction kind total_cents interval_months].freeze

      before_action { authorize Projection }
      before_action :require_period

      def show
        render json: { data: projection_json(projection) }
      end

      def simulation
        simulation = ProjectionSimulation.new(user: current_user, inputs: simulation_inputs)
        return render_validation_errors(simulation) unless simulation.call

        render json: { data: { baseline: projection_json(projection), simulated: projection_json(projection(simulation.entries)) } }
      end

      private

      def require_period
        return render_error(status: :bad_request, code: "invalid_month", message: "from must be a month (YYYY-MM)") unless from

        render_error(status: :bad_request, code: "invalid_months", message: "months must be an integer from 1 to 24 or all") unless months
      end

      def projection(extra_entries = [])
        Projection.new(user: current_user, from: from, months: months, extra_entries: extra_entries)
      end

      def projection_json(projection)
        { anchor: anchor_json(projection.anchor), months: projection.months, alerts: projection.alerts, last_entry_month: projection.last_entry_month }
      end

      def simulation_inputs
        params.permit(entries: SIMULATION_ENTRY_FIELDS).fetch(:entries, [])
      end

      def from
        return @from if defined?(@from)

        @from = if params[:from].blank?
          Date.current.beginning_of_month
        elsif MONTH_FORMAT.match?(params[:from].to_s)
          Date.strptime(params[:from].to_s, "%Y-%m")
        end
      end

      def months
        return Projection::DEFAULT_MONTHS if params[:months].blank?
        return Projection::ALL_MONTHS if params[:months].to_s == Projection::ALL_MONTHS.to_s

        value = Integer(params[:months].to_s, 10, exception: false)
        value if Projection::MONTHS_RANGE.cover?(value)
      end

      def anchor_json(balance)
        balance && { amount_cents: balance.amount_cents, as_of: balance.as_of.iso8601 }
      end
    end
  end
end
