require "openapi_first"
require_relative "parallel_openapi_coverage"

OpenapiFirst::Test.setup do |test|
  test.register(OpenapiFirst.load(Rails.root.join("docs/openapi.yaml").to_s, path_prefix: "/api/v1"))
  test.ignore_request_error { |request| !request.path.start_with?("/api/v1/") }
  test.report_coverage = false if ParallelOpenapiCoverage.worker?
end

OpenapiFirst::Test.observe(Rails.application)

ParallelOpenapiCoverage.install
