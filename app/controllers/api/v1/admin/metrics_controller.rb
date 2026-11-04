module Api
  module V1
    module Admin
      class MetricsController < BaseController
        def show
          render json: { data: AdminMetrics.new.to_h }
        end
      end
    end
  end
end
