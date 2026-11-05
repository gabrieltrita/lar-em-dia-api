require "rails_helper"

RSpec.describe DueAlertsJob do
  include ActiveJob::TestHelper

  let(:bills) { create(:category, :expense) }
  let(:now) { Time.utc(2026, 11, 10, 11) }

  def bill(user, due_on, **attributes)
    create(:entry, user: user, category: bills, due_on: due_on, amount_cents: 12_345, **attributes)
  end

  def deliveries_for(user)
    enqueued_jobs.select { |job| job["job_class"] == "ActionMailer::MailDeliveryJob" && job["arguments"].to_s.include?(user.to_global_id.to_s) }
  end

  it "emails users at 8h in their time zone with a pending expense due in their chosen days" do
    sao_paulo = create(:user)
    lisbon = create(:user, time_zone: "Europe/Lisbon")
    bill(sao_paulo, "2026-11-11")
    bill(lisbon, "2026-11-11")

    described_class.perform_now(now)

    expect(deliveries_for(sao_paulo).size).to eq(1)
    expect(deliveries_for(lisbon)).to be_empty
    expect(sao_paulo.reload.due_alerts_sent_on).to eq(Date.new(2026, 11, 10))
  end

  it "sends once a day" do
    user = create(:user)
    bill(user, "2026-11-11")

    2.times { described_class.perform_now(now) }

    expect(deliveries_for(user).size).to eq(1)
  end

  it "skips users without something due, with alerts off, deactivated or unconfirmed" do
    nothing_due = create(:user, due_alert_days_before: 3)
    bill(nothing_due, "2026-11-11")
    paid = create(:user)
    bill(paid, "2026-11-11", status: :paid, paid_on: "2026-11-09")
    off = create(:user, due_alerts_enabled: false)
    bill(off, "2026-11-11")
    deactivated = create(:user, deactivated_at: 1.day.ago)
    bill(deactivated, "2026-11-11")
    unconfirmed = create(:user, :unconfirmed)
    bill(unconfirmed, "2026-11-11")
    income = create(:user)
    create(:entry, user: income, category: create(:category), due_on: "2026-11-11")

    described_class.perform_now(now)

    expect(enqueued_jobs).to be_empty
  end

  it "defaults to the current time" do
    user = create(:user, due_alert_days_before: 0)
    travel_to(now) do
      bill(user, "2026-11-10")
      described_class.perform_now
    end

    expect(deliveries_for(user).size).to eq(1)
  end
end
