# Falha rápido: em produção a aplicação NÃO sobe sem os segredos corretos
# (melhor quebrar no deploy do que rodar com JWT fraco ou sem criptografia).
require Rails.root.join("lib/trita/env_validator").to_s

Trita::EnvValidator.validate! if Rails.env.production? && ENV["SKIP_ENV_VALIDATION"] != "true"
