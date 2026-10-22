require "rails_helper"
require "rake"

RSpec.describe "encryption:reencrypt" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "encryption:reencrypt" }
  end

  def raw_first_name(user)
    User.connection.select_value("SELECT first_name FROM users WHERE id = #{User.connection.quote(user.id)}")
  end

  it "re-encrypts every model, read-only ones included, keeping the data readable" do
    user = create(:user, first_name: "Rotated")
    AuditLog.record!("auth.login", target: user, actor: user)
    Consent.record!(user, "terms", true)
    Auth::TokenIssuer.call(user)
    before = raw_first_name(user)

    expect { Rake::Task["encryption:reencrypt"].execute }.to output(/User: 1 re-encrypted.*AuditLog: 1 re-encrypted.*Consent: 1 re-encrypted/m).to_stdout

    expect(raw_first_name(user)).not_to eq(before)
    expect(user.reload.first_name).to eq("Rotated")
    expect(AuditLog.last).to be_readonly
  end
end
