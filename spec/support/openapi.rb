require "openapi_first"

OpenapiFirst::Test.setup do |test|
  test.register(OpenapiFirst.load(Rails.root.join("docs/openapi.yaml").to_s, path_prefix: "/api/v1"))
  test.ignore_request_error { |request| !request.path.start_with?("/api/v1/") }
end

OpenapiFirst::Test.observe(Rails.application)
