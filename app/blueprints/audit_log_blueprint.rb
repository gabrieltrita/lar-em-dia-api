class AuditLogBlueprint < Blueprinter::Base
  identifier :id

  fields :action, :actor_id, :target_type, :target_id, :metadata, :ip_address, :user_agent, :request_id, :created_at
end
