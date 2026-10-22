require "rails_helper"

RSpec.describe User do
  def raw_row(user, columns)
    User.connection.select_one("SELECT #{columns} FROM users WHERE id = #{User.connection.quote(user.id)}")
  end

  describe "validações" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to define_enum_for(:role).with_values(user: 0, admin: 1) }

    it "exige senha forte" do
      user = build(:user, password: "fraquinha")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "não permite e-mail duplicado (case insensitive)" do
      create(:user, email: "dup@example.com")
      expect(build(:user, email: "DUP@example.com")).not_to be_valid
    end
  end

  describe "criptografia" do
    let!(:user) { create(:user, :with_2fa, email: "secreto@example.com", first_name: "Maria", phone: "+5511988887777") }

    it "não armazena dados pessoais em texto puro" do
      raw = raw_row(user, "email, first_name, last_name, phone, otp_secret")

      expect(raw["email"]).not_to include("secreto")
      expect(raw["first_name"]).not_to include("Maria")
      expect(raw["phone"]).not_to include("5511988887777")
      expect(raw["otp_secret"]).not_to include(user.otp_secret)
    end

    it "descriptografa transparentemente" do
      reloaded = User.find(user.id)
      expect(reloaded.email).to eq("secreto@example.com")
      expect(reloaded.first_name).to eq("Maria")
    end

    it "permite buscar por e-mail (criptografia determinística)" do
      expect(User.find_by(email: "SECRETO@example.com ")).to eq(user)
    end
  end

  describe "bloqueio progressivo" do
    let(:user) { create(:user) }

    it "bloqueia na 5ª falha por 15 minutos e avisa por e-mail" do
      4.times { user.register_failed_login! }
      expect(user).not_to be_access_locked

      expect { user.register_failed_login! }.to have_enqueued_mail(UserMailer, :account_locked)
      expect(user).to be_access_locked
      expect(user.locked_until).to be_within(5.seconds).of(15.minutes.from_now)
    end

    it "dobra o tempo a cada nova falha, até 24h" do
      5.times { user.register_failed_login! }
      user.register_failed_login!
      expect(user.locked_until).to be_within(5.seconds).of(30.minutes.from_now)

      20.times { user.register_failed_login! }
      expect(user.locked_until).to be_within(5.seconds).of(24.hours.from_now)
    end

    it "desbloqueia quando a senha é trocada" do
      5.times { user.register_failed_login! }
      user.update!(password: "Nova@12345")
      expect(user.reload).not_to be_access_locked
    end
  end

  describe "troca de senha" do
    let(:user) { create(:user) }

    it "derruba todas as sessões, audita e avisa o usuário" do
      tokens = tokens_for(user)
      expect {
        user.update!(password: "Nova@12345")
      }.to have_enqueued_mail(UserMailer, :password_changed)

      expect(user.refresh_tokens.active).to be_empty
      expect(RefreshToken.find_by_raw_token(tokens[:refresh_token])).to be_revoked
      expect(AuditLog.where(action: "user.password_changed", target_id: user.id)).to exist
    end
  end

  describe "#anonymize!" do
    let(:user) { create(:user, :with_2fa, email: "titular@example.com", first_name: "Joana", phone: "+5511911112222") }

    it "remove dados pessoais, mantém criptografia e encerra sessões" do
      tokens_for(user)
      user.anonymize!
      user.reload

      expect(user).to be_anonymized
      expect(user.email).to eq("anon-#{user.id}@anonymized.invalid")
      expect(user.first_name).to eq("Usuário")
      expect(user.phone).to be_nil
      expect(user).not_to be_two_factor_enabled
      expect(user.refresh_tokens.active).to be_empty
      expect(User.find_by(email: "titular@example.com")).to be_nil
      expect(raw_row(user, "first_name")["first_name"]).not_to include("Usuário")
    end
  end

  describe "2FA" do
    let(:user) { create(:user) }

    it "ativa com código válido e gera 10 códigos de backup de uso único" do
      user.generate_otp_secret!
      codes = user.enable_two_factor!(otp_code(user))

      expect(user).to be_two_factor_enabled
      expect(codes.size).to eq(10)
      expect(user.verify_second_factor(codes.first)).to be(true)
      expect(user.verify_second_factor(codes.first)).to be(false)
      expect(user.backup_codes_remaining).to eq(9)
    end

    it "não aceita o mesmo código TOTP duas vezes (replay)" do
      user.update!(otp_secret: ROTP::Base32.random, otp_enabled_at: Time.current)
      code = otp_code(user)

      expect(user.verify_otp(code)).to be(true)
      expect(user.verify_otp(code)).to be(false)
    end

    it "não guarda os códigos de backup em claro" do
      user.generate_otp_secret!
      codes = user.enable_two_factor!(otp_code(user))
      expect(user.otp_backup_code_digests).not_to include(codes.first)
    end
  end
end
