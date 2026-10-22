# Regra de segurança: os jobs de e-mail recebem só o usuário (GlobalID).
# Tokens são gerados aqui dentro, na hora do envio, e existem apenas no corpo
# do e-mail — nunca no Redis, nos logs ou no painel do Sidekiq.
class UserMailer < ApplicationMailer
  def confirmation_instructions(user)
    @user = user
    @url = frontend_url("/confirm-email?token=#{CGI.escape(user.generate_token_for(:email_confirmation))}")
    mail to: @user.email, subject: "Confirme seu e-mail"
  end

  def registration_attempt(user)
    @user = user
    @login_url = frontend_url("/login")
    @forgot_url = frontend_url("/forgot-password")
    mail to: @user.email, subject: "Tentativa de cadastro com seu e-mail"
  end

  def welcome(user)
    @user = user
    @login_url = frontend_url("/login")
    mail to: @user.email, subject: "Bem-vindo(a) à Trita!"
  end

  def password_reset(user)
    @user = user
    @url = frontend_url("/reset-password?token=#{CGI.escape(user.generate_token_for(:password_reset))}")
    mail to: @user.email, subject: "Redefinição de senha"
  end

  def password_changed(user)
    @user = user
    @forgot_url = frontend_url("/forgot-password")
    mail to: @user.email, subject: "Sua senha foi alterada"
  end

  def email_change_confirmation(user)
    @user = user
    @url = frontend_url("/confirm-email-change?token=#{CGI.escape(user.generate_token_for(:email_change))}")
    mail to: @user.unconfirmed_email, subject: "Confirme seu novo e-mail"
  end

  def email_change_requested(user)
    @user = user
    @forgot_url = frontend_url("/forgot-password")
    mail to: @user.email, subject: "Pedido de troca de e-mail"
  end

  def account_locked(user)
    @user = user
    @locked_until = user.locked_until
    @forgot_url = frontend_url("/forgot-password")
    mail to: @user.email, subject: "Sua conta foi bloqueada temporariamente"
  end

  def two_factor_disabled(user)
    @user = user
    @forgot_url = frontend_url("/forgot-password")
    mail to: @user.email, subject: "Verificação em duas etapas desativada"
  end
end
