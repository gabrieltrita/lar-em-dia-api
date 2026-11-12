require "json"

module ParallelOpenapiCoverage
  CoveredTask = Data.define(:key) do
    def known? = true
    def error = nil
    def response_definition = self
  end

  module_function

  def install
    at_exit { worker? ? save : merge } if parallel?
  end

  def parallel?
    ENV.key?("TEST_ENV_NUMBER") && ENV.key?("PARALLEL_PID_FILE")
  end

  def worker?
    parallel? && !ParallelTests.first_process?
  end

  def save
    directory.mkpath
    directory.join("#{Process.pid}.json").write(JSON.generate(covered_keys))
  end

  def merge
    ParallelTests.wait_for_other_processes_to_finish
    directory.glob("*.json").each { |file| JSON.parse(file.read).each { |key| track(key) } }
    directory.rmtree if directory.exist?
  end

  def covered_keys
    OpenapiFirst::Test::Coverage.result.plans.flat_map do |plan|
      plan.tasks.select(&:finished?).map(&:key)
    end
  end

  def track(key)
    OpenapiFirst::Test::Coverage.track_response(CoveredTask.new(key), nil, OpenapiFirst::Test[:default])
  end

  def directory
    Rails.root.join("tmp/openapi_coverage", File.basename(ENV.fetch("PARALLEL_PID_FILE")))
  end
end
