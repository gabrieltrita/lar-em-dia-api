Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:5173").split(",").map(&:strip))

    resource "*",
      headers: %w[Authorization Content-Type Accept X-Token-Transport X-Request-Id],
      methods: %i[get post put patch delete options head],
      expose: %w[X-Request-Id Retry-After],
      credentials: true,
      max_age: 600
  end
end
