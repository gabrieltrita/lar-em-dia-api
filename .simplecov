SimpleCov.configure do
  enable_coverage :branch
  cover "{app,lib}/**/*.rb"
  merging ENV.key?("PARALLEL_PID_FILE")

  coverage :line, minimum: 100
  coverage :branch, minimum: 100
end
