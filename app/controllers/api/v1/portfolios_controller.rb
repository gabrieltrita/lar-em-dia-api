module Api
  module V1
    class PortfoliosController < ApplicationController
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
