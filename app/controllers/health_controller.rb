class HealthController < ActionController::API
  def show
    result = HealthCheck.call
    render json: result, status: result[:status] == HealthCheck::DOWN ? :service_unavailable : :ok
  end
end
