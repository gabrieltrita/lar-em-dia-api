require "rails_helper"

RSpec.describe "GET /health", type: :request do
  def stub_health(status)
    allow(HealthCheck).to receive(:call).and_return(status: status, checks: { database: "ok", cache: "ok", sidekiq: status })
  end

  it "answers 200 with only the statuses and no authentication" do
    stub_health("ok")
    get "/health"

    expect(response).to have_http_status(:ok)
    expect(json).to eq("status" => "ok", "checks" => { "database" => "ok", "cache" => "ok", "sidekiq" => "ok" })
  end

  it "keeps answering 200 when degraded" do
    stub_health("degraded")
    get "/health"

    expect(response).to have_http_status(:ok)
    expect(json["status"]).to eq("degraded")
  end

  it "answers 503 when down" do
    stub_health("down")
    get "/health"

    expect(response).to have_http_status(:service_unavailable)
    expect(json["status"]).to eq("down")
  end
end
