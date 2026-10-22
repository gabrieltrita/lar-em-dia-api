source "https://rubygems.org"

gem "rails", "~> 8.1.1"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Autenticação
gem "bcrypt", "~> 3.1.7"
gem "jwt", "~> 2.9"

# 2FA (TOTP)
gem "rotp", "~> 6.3"

# Autorização (policies por role)
gem "pundit", "~> 2.4"

# CORS para o front (trita-web)
gem "rack-cors"

# Rate limiting / proteção contra brute force
gem "rack-attack"

# Redis + jobs em background
gem "redis", "~> 5.3"
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 2.0"

# Monitoramento de erros (ativo só com SENTRY_DSN definido)
gem "sentry-ruby", "~> 7.1"
gem "sentry-rails", "~> 7.1"
gem "sentry-sidekiq", "~> 7.1"

# Paginação
gem "pagy", "~> 9.3"

# Serialização JSON
gem "blueprinter", "~> 1.1"

# Traduções pt-BR das mensagens padrão do Rails
gem "rails-i18n", "~> 8.0"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false

  gem "dotenv-rails"
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "shoulda-matchers", "~> 6.4"
end
