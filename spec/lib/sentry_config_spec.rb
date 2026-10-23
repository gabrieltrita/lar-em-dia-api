require "rails_helper"

RSpec.describe SentryConfig do
  it "filters exception messages but keeps the class and the stacktrace" do
    with_sentry do |transport|
      begin
        raise ArgumentError, "Key (email)=(someone@example.com) already exists"
      rescue ArgumentError => error
        Sentry.capture_exception(error)
      end

      exception = transport.events.sole.exception.values.last
      expect(exception.type).to eq("ArgumentError")
      expect(exception.value).to eq("[FILTERED]")
      expect(exception.stacktrace.frames).not_to be_empty
    end
  end

  it "filters manual messages" do
    with_sentry do |transport|
      Sentry.capture_message("Contact someone@example.com")
      expect(transport.events.sole.message).to eq("[FILTERED]")
    end
  end

  it "keeps only the user id" do
    with_sentry do |transport|
      Sentry.set_user(id: "user-1", email: "someone@example.com", ip_address: "10.0.0.1")
      Sentry.capture_message("x")
      expect(transport.events.sole.user).to eq(id: "user-1")
    end
  end

  it "drops Sidekiq job arguments from the context" do
    with_sentry do |transport|
      Sentry.with_scope do |scope|
        scope.set_contexts(sidekiq: { "class" => "SomeJob", "jid" => "abc", "args" => [ "someone@example.com" ] })
        Sentry.capture_message("x")
      end

      expect(transport.events.sole.contexts[:sidekiq]).to eq("class" => "SomeJob", "jid" => "abc")
    end
  end

  it "records breadcrumbs without SQL text or cache keys" do
    with_sentry do |transport|
      Rails.cache.read("rack::attack:1:auth/login/email:someone@example.com")
      User.where(email: "someone@example.com").to_a
      Sentry.capture_message("x")

      crumbs = transport.events.sole.breadcrumbs.to_h[:values]
      expect(crumbs.map { |crumb| crumb[:category] }).to include("cache_read.active_support", "sql.active_record")
      expect(crumbs.map { |crumb| crumb[:data] }).to all(satisfy { |data| !data.key?(:key) && !data.key?(:sql) })
      expect(sentry_payload(transport.events.sole)).not_to include("someone@example.com")
    end
  end
end
