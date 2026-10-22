# Contexto da requisição atual (usado pela auditoria).
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :ip_address, :user_agent, :request_id
end
