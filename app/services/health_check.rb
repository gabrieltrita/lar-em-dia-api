require "sidekiq/api"

class HealthCheck
  OK = "ok".freeze
  DEGRADED = "degraded".freeze
  DOWN = "down".freeze
  QUEUE_LATENCY_LIMIT = 5.minutes

  def self.call
    new.call
  end

  def call
    checks = { database: database, cache: cache, sidekiq: sidekiq }
    { status: overall(checks), checks: checks }
  end

  private

  def overall(checks)
    if checks.values_at(:database, :cache).include?(DOWN)
      DOWN
    elsif checks.values.all?(OK)
      OK
    else
      DEGRADED
    end
  end

  def database
    ActiveRecord::Base.connection.select_value("SELECT 1")
    OK
  rescue StandardError
    DOWN
  end

  def cache
    key = "health:#{SecureRandom.hex(8)}"
    Rails.cache.write(key, key, expires_in: 1.minute)
    Rails.cache.read(key) == key ? OK : DOWN
  ensure
    Rails.cache.delete(key)
  end

  def sidekiq
    return DEGRADED if Sidekiq::ProcessSet.new(false).size.zero?
    return DEGRADED if Sidekiq::Queue.all.any? { |queue| queue.latency > QUEUE_LATENCY_LIMIT }

    OK
  rescue StandardError
    DEGRADED
  end
end
