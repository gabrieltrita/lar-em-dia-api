module Api
  module V1
    class ProjectionsController < ApplicationController
      include ProjectionPeriod

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
        @from = parse_projection_month(params[:from])
        @months = parse_projection_months(params[:months])
        render_projection_period_error(@from, @months)
      end

      def projection(extra_entries = [])
        Projection.new(user: current_user, from: @from, months: @months, extra_entries: extra_entries,
          include_investment_income: params[:include_investment_income].to_s != "false")
      end

      def simulation_inputs
        params.permit(entries: SIMULATION_ENTRY_FIELDS).fetch(:entries, [])
      end
    end
  end
end
