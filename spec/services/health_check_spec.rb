require "rails_helper"

RSpec.describe HealthCheck do
  let(:processes) { 1 }
  let(:queues) { [ instance_double(Sidekiq::Queue, latency: 2.0) ] }

  before do
    allow(Sidekiq::ProcessSet).to receive(:new).with(false).and_return(instance_double(Sidekiq::ProcessSet, size: processes))
    allow(Sidekiq::Queue).to receive(:all).and_return(queues)
  end

  it "is ok when the database, the cache and Sidekiq answer" do
    expect(described_class.call).to eq(status: "ok", checks: { database: "ok", cache: "ok", sidekiq: "ok" })
  end

  it "leaves no key behind in the cache" do
    allow(Rails.cache).to receive(:delete).and_call_original
    described_class.call
    expect(Rails.cache).to have_received(:delete).with(/\Ahealth:\h{16}\z/)
  end

  it "is down when the database fails" do
    allow(ActiveRecord::Base.connection).to receive(:select_value).and_raise(ActiveRecord::ConnectionNotEstablished)
    expect(described_class.call).to eq(status: "down", checks: { database: "down", cache: "ok", sidekiq: "ok" })
  end

  it "is down when the cache cannot keep a value, as RedisCacheStore swallows connection errors" do
    allow(Rails.cache).to receive(:read).and_return(nil)
    expect(described_class.call).to eq(status: "down", checks: { database: "ok", cache: "down", sidekiq: "ok" })
  end

  context "with Sidekiq problems the API keeps serving" do
    context "without any Sidekiq process" do
      let(:processes) { 0 }

      it { expect(described_class.call).to eq(status: "degraded", checks: { database: "ok", cache: "ok", sidekiq: "degraded" }) }
    end

    context "with a queue waiting longer than the limit" do
      let(:queues) { [ instance_double(Sidekiq::Queue, latency: 1.0), instance_double(Sidekiq::Queue, latency: 301.0) ] }

      it { expect(described_class.call[:checks][:sidekiq]).to eq("degraded") }
    end

    it "is degraded when Sidekiq's Redis is unreachable" do
      allow(Sidekiq::ProcessSet).to receive(:new).and_raise(RedisClient::CannotConnectError)
      expect(described_class.call).to eq(status: "degraded", checks: { database: "ok", cache: "ok", sidekiq: "degraded" })
    end
  end

  it "is down, not degraded, when a critical check fails together with Sidekiq" do
    allow(Sidekiq::ProcessSet).to receive(:new).and_raise(RedisClient::CannotConnectError)
    allow(Rails.cache).to receive(:read).and_return(nil)
    expect(described_class.call[:status]).to eq("down")
  end
end
