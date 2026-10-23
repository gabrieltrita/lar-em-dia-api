require "rails_helper"

RSpec.describe ErrorHandling, type: :controller do
  def self.production_controller
    original = Rails.env
    Rails.env = "production"
    Class.new(ActionController::API) do
      include ErrorHandling

      def self.name = "ProductionController"
    end
  ensure
    Rails.env = original
  end

  controller(production_controller) do
    def index
      raise "secret detail"
    end
  end

  it "answers unexpected errors with a generic 500 that leaks nothing" do
    get :index

    expect(response).to have_http_status(:internal_server_error)
    expect(JSON.parse(response.body)).to eq("error" => { "code" => "internal_error", "message" => "Internal server error" })
  end

  it "logs the error class and backtrace but never its message" do
    logged = []
    allow(Rails.logger).to receive(:error) { |entry| logged << entry }
    get :index

    expect(logged.sole).to include(error: "RuntimeError")
    expect(logged.sole[:backtrace].first).to include("error_handling_spec.rb")
    expect(logged.sole.to_s).not_to include("secret detail")
  end

  it "reports the error to Sentry when enabled" do
    with_sentry do |transport|
      get :index
      expect(transport.events.map { |e| e.exception.values.last.type }).to eq([ "RuntimeError" ])
    end
  end
end
