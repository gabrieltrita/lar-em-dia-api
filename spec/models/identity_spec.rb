require "rails_helper"

RSpec.describe Identity do
  subject { build(:identity) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:provider_uid) }
  it { is_expected.to define_enum_for(:provider).with_values(google: "google", apple: "apple").backed_by_column_of_type(:string) }

  it "rejects an unknown provider" do
    identity = build(:identity, provider: "myspace")
    expect(identity).not_to be_valid
    expect(identity.errors.details[:provider]).to include(error: :inclusion, value: "myspace")
  end

  it "rejects the same provider account linked to two users" do
    create(:identity, provider: :google, provider_uid: "shared")
    duplicate = build(:identity, provider: :google, provider_uid: "shared")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors.details[:provider_uid]).to include(error: :taken, value: "shared")
  end

  it "allows the same uid on a different provider" do
    create(:identity, provider: :google, provider_uid: "same")
    expect(build(:identity, provider: :apple, provider_uid: "same")).to be_valid
  end

  it "rejects a second identity of the same provider for one user" do
    user = create(:user)
    create(:identity, user: user, provider: :google)

    expect(build(:identity, user: user, provider: :google)).not_to be_valid
    expect(build(:identity, user: user, provider: :apple)).to be_valid
  end

  it "normalizes and validates the linked email" do
    expect(build(:identity, email_at_link: "  Person@Example.COM ").email_at_link).to eq("person@example.com")
    expect(build(:identity, email_at_link: "not-an-email")).not_to be_valid
    expect(build(:identity, email_at_link: nil)).to be_valid
  end

  it "encrypts the uid deterministically and the linked email at rest" do
    identity = create(:identity, provider_uid: "uid-123", email_at_link: "person@example.com")
    row = described_class.connection.select_one("SELECT provider_uid, email_at_link FROM identities WHERE id = #{described_class.connection.quote(identity.id)}")

    expect(row["provider_uid"]).not_to include("uid-123")
    expect(row["email_at_link"]).not_to include("person@example.com")
    expect(described_class.find_by(provider: :google, provider_uid: "uid-123")).to eq(identity)
  end
end
