require "rails_helper"

RSpec.describe DueAlertMailer, type: :mailer do
  let(:frontend) { ENV.fetch("FRONTEND_URL", "http://localhost:5173") }
  let(:user) { create(:user, first_name: "Ana", due_alerts_sent_on: Date.new(2026, 11, 10)) }
  let(:bills) { create(:category, :expense) }

  before do
    create(:entry, user: user, category: bills, description: "Electricity", amount_cents: 123_456, due_on: "2026-11-11")
    create(:entry, user: user, category: bills, description: "Paid already", due_on: "2026-11-11", status: :paid, paid_on: "2026-11-09")
    create(:entry, user: user, category: bills, description: "Next week", due_on: "2026-11-18")
  end

  it "lists the pending expenses due on the alert day with an unsubscribe link" do
    mail = described_class.upcoming(user)
    text = mail.text_part.body.decoded

    expect(mail.to).to eq([ user.email ])
    expect(mail.subject).to eq("Bills due tomorrow")
    expect(text).to include("Hi Ana", "November 11, 2026", "Electricity: R$ 1.234,56", "#{frontend}/expenses")
    expect(text).not_to include("Paid already", "Next week")
    expect(mail.html_part.body.decoded).to include("Electricity")

    token = CGI.unescape(text[/#{Regexp.escape("#{frontend}/unsubscribe?token=")}(\S+)/, 1])
    expect(User.find_by_token_for(:due_alerts_unsubscribe, token)).to eq(user)
  end

  it "names the day in the subject" do
    user.update!(due_alert_days_before: 0)
    expect(described_class.upcoming(user).subject).to eq("Bills due today")

    user.update!(due_alert_days_before: 7)
    expect(described_class.upcoming(user).subject).to eq("Bills due in 7 days")
  end
end
