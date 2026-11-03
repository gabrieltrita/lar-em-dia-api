require "rails_helper"

RSpec.describe "Errors reported to Sentry", type: :request do
  let(:user) { create(:user) }

  it "strips the body, cookies, sensitive headers and personal data" do
    headers = auth_headers(user).merge("Cookie" => "trita_refresh=secret-cookie", "X-Token-Transport" => "cookie", "User-Agent" => "PrivateAgent/1.0", "REMOTE_ADDR" => "203.0.113.9")
    allow_any_instance_of(User).to receive(:update).and_raise(RuntimeError, "Duplicate for someone@example.com")

    with_sentry do |transport|
      expect {
        patch "/api/v1/me", params: { first_name: "Private title" }, headers: headers, as: :json
      }.to raise_error(RuntimeError)

      event = transport.events.sole
      expect(event.request.data).to be_nil
      expect(event.request.cookies).to eq({})
      expect(event.request.headers.keys.map(&:downcase)).not_to include("authorization", "cookie", "x-token-transport", "user-agent")
      expect(event.request.env.keys).to contain_exactly("SERVER_NAME", "SERVER_PORT")
      expect(event.tags[:request_id]).to be_present
      expect(sentry_payload(event)).not_to include("someone@example.com", "Private title", headers["Authorization"].split.last, "secret-cookie", "PrivateAgent", "203.0.113.9")
    end
  end

  it "never collects the query string" do
    admin = create(:user, :admin)
    allow(UserBlueprint).to receive(:render_as_hash).and_raise(RuntimeError, "boom")

    with_sentry do |transport|
      expect { get "/api/v1/admin/users?page=someone@example.com", headers: auth_headers(admin) }.to raise_error(RuntimeError)

      event = transport.events.sole
      expect(event.request.query_string).to be_nil
      expect(sentry_payload(event)).not_to include("someone@example.com")
    end
  end
end
