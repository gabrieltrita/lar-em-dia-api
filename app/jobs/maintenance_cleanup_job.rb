class MaintenanceCleanupJob < ApplicationJob
  queue_as :default

  UNCONFIRMED_TTL = 7.days

  def perform
    tokens = RefreshToken.where(expires_at: ...1.day.ago).delete_all
    users = User.where(confirmed_at: nil, anonymized_at: nil).where(created_at: ...UNCONFIRMED_TTL.ago).destroy_all.size

    Rails.logger.info("[MaintenanceCleanupJob] refresh_tokens=#{tokens} unconfirmed_users=#{users}")
  end
end
