require "rails_helper"

RSpec.describe MaintenanceCleanupJob do
  it "deletes expired refresh tokens and keeps valid ones" do
    user = create(:user)
    valid = RefreshToken.find_by_raw_token(Auth::TokenIssuer.call(user)[:refresh_token])
    expired = RefreshToken.find_by_raw_token(Auth::TokenIssuer.call(user)[:refresh_token])
    expired.update_columns(expires_at: 2.days.ago)

    described_class.perform_now

    expect(RefreshToken.exists?(valid.id)).to be(true)
    expect(RefreshToken.exists?(expired.id)).to be(false)
  end

  it "removes sign-ups left unconfirmed for over 7 days" do
    old_pending = create(:user, :unconfirmed, created_at: 8.days.ago)
    recent_pending = create(:user, :unconfirmed, created_at: 1.day.ago)
    old_confirmed = create(:user, created_at: 30.days.ago)

    described_class.perform_now

    expect(User.exists?(old_pending.id)).to be(false)
    expect(User.exists?(recent_pending.id)).to be(true)
    expect(User.exists?(old_confirmed.id)).to be(true)
  end

  it "is scheduled in sidekiq-cron" do
    schedule = YAML.load_file(Rails.root.join("config/schedule.yml"))
    expect(schedule.dig("maintenance_cleanup", "class")).to eq("MaintenanceCleanupJob")
  end
end
