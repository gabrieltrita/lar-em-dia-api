require "rails_helper"

RSpec.describe "Request logging", type: :request do
  def payload_of
    payloads = []
    callback = ->(*, payload) { payloads << payload }
    ActiveSupport::Notifications.subscribed(callback, "process_action.action_controller") { yield }
    payloads.last
  end

  it "adds the request id and the user id to authenticated requests" do
    user = create(:user)
    payload = payload_of { get "/api/v1/me", headers: auth_headers(user) }

    expect(payload[:request_id]).to eq(response.headers["X-Request-Id"])
    expect(payload[:user_id]).to eq(user.id)
  end

  it "leaves the user id empty on public endpoints" do
    payload = payload_of { post "/api/v1/auth/login", params: { email: "nobody@example.com", password: "Wrong@123" }, as: :json }

    expect(payload[:request_id]).to be_present
    expect(payload[:user_id]).to be_nil
  end

  describe "lograge fields" do
    let(:custom_options) { Rails.application.config.lograge.custom_options }

    it "keeps only the request id, the user id and the exception class" do
      event = ActiveSupport::Notifications::Event.new("process_action.action_controller", nil, nil, "1", {
        request_id: "req-1", user_id: "user-1", exception: [ "ActiveRecord::RecordNotFound", "Couldn't find User with email=someone@example.com" ],
        params: { "password" => "secret" }
      })

      expect(custom_options.call(event)).to eq(request_id: "req-1", user_id: "user-1", error: "ActiveRecord::RecordNotFound")
    end

    it "drops empty fields" do
      event = ActiveSupport::Notifications::Event.new("process_action.action_controller", nil, nil, "2", { request_id: "req-2" })
      expect(custom_options.call(event)).to eq(request_id: "req-2")
    end
  end
end
