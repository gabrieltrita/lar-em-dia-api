require Rails.root.join("lib/trita/env_validator").to_s

Trita::EnvValidator.validate! if Rails.env.production? && ENV["SKIP_ENV_VALIDATION"] != "true"
