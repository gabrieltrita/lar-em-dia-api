module Api
  module V1
    class PortfoliosController < ApplicationController
      SIMULATION_FIELDS = %i[kind initial_cents monthly_cents months ticker monthly_yield_bps annual_rate_bps reinvest target_monthly_income_cents].freeze

      before_action { authorize :portfolio }

      def show
        portfolio = Portfolio.new(user: current_user, goal: params[:goal], include_closed: params[:include_closed] == "true")
        render json: {
          data: { totals: portfolio.totals, goals: portfolio.goals, positions: portfolio.positions.map { |item| position_json(item) } }
        }
      end

      def history
        render json: { data: PortfolioHistory.new(user: current_user).months }
      end

      def income
        months = params[:months].blank? ? DistributionIncome::DEFAULT_MONTHS : Integer(params[:months].to_s, 10, exception: false)
        unless DistributionIncome::MONTHS_RANGE.cover?(months)
          return render_error(status: :bad_request, code: "invalid_months", message: "months must be an integer from 1 to 60")
        end

        income = DistributionIncome.new(user: current_user)
        render json: {
          data: { monthly_average_cents: income.monthly_average_cents, received: income.received, forecast: income.forecast(months),
                  positions: income.positions }
        }
      end

      def simulation
        simulation = PortfolioSimulation.new(params.permit(*SIMULATION_FIELDS).to_h)
        return render_validation_errors(simulation) unless simulation.valid?

        render json: { data: simulation.result }
      end

      private

      def position_json(item)
        asset = item.position.asset
        {
          ticker: asset.ticker, name: asset.name, asset_type: asset.asset_type, goal: item.position.goal,
          quantity: item.state.quantity, average_price_e8: item.state.average_price_e8, cost_cents: item.state.cost_cents,
          contributed_cents: item.state.contributed_cents, realized_cents: item.state.realized_cents,
          quote: item.quote && AssetQuoteBlueprint.render_as_hash(item.quote),
          market_value_cents: item.market_value_cents, gain_cents: item.gain_cents
        }
      end
    end
  end
end
