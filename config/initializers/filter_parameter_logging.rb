# Nunca loga dados sensíveis / pessoais
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :first_name, :last_name, :phone, :document, :birth_date, :authorization
]
