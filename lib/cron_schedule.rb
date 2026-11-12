module CronSchedule
  module_function

  def disabled_jobs(env = ENV)
    env.fetch("DISABLED_CRON_JOBS", "").split(",").map(&:strip).reject(&:empty?)
  end

  def remove_disabled!(env = ENV)
    disabled_jobs(env).each { |name| Sidekiq::Cron::Job.destroy(name) }
  end
end
