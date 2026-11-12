module Api
  module V1
    class InvestmentPositionsController < ApplicationController
      def update
        position = policy_scope(InvestmentPosition).joins(:asset).find_by!(assets: { ticker: params[:ticker].to_s.upcase })
        authorize position
        position.update!(params.permit(:goal))
        render json: { data: InvestmentPositionBlueprint.render_as_hash(position) }
      end
    end
  end
end
