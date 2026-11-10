require "rails_helper"

RSpec.describe "Routes" do
  def sidekiq_mounted?
    Rails.application.routes.routes.any? { |route| route.path.spec.to_s.start_with?("/sidekiq") }
  end

  def with_routes_in_production(env)
    allow(Rails.env).to receive(:local?).and_return(false)
    stub_const("ENV", ENV.to_h.merge(env))
    Rails.application.reload_routes!
    yield
  ensure
    allow(Rails.env).to receive(:local?).and_call_original
    stub_const("ENV", ENV.to_h.except("ENABLE_SIDEKIQ_WEB"))
    Rails.application.reload_routes!
  end

  it "keeps the Sidekiq dashboard unmounted in production by default" do
    with_routes_in_production("ENABLE_SIDEKIQ_WEB" => nil) { expect(sidekiq_mounted?).to be(false) }
  end

  it "mounts the Sidekiq dashboard in production when ENABLE_SIDEKIQ_WEB is true" do
    with_routes_in_production("ENABLE_SIDEKIQ_WEB" => "true") { expect(sidekiq_mounted?).to be(true) }
  end

  it "mounts the Sidekiq dashboard in development and test" do
    expect(sidekiq_mounted?).to be(true)
  end
end
