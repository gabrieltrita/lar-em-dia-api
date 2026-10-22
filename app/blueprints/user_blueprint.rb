class UserBlueprint < Blueprinter::Base
  identifier :id

  fields :email, :first_name, :last_name, :full_name, :phone, :role, :created_at, :updated_at

  field(:email_confirmed) { |user, _| user.confirmed? }
  field(:two_factor_enabled) { |user, _| user.two_factor_enabled? }

  # Visão do próprio usuário (GET /me)
  view :self do
    field :unconfirmed_email, name: :pending_email
  end

  view :admin do
    fields :last_sign_in_at, :sign_in_count, :password_changed_at, :confirmed_at, :failed_login_attempts, :locked_until
    field(:locked) { |user, _| user.access_locked? }
  end
end
