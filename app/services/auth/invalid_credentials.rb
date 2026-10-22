module Auth
  class InvalidCredentials < Unauthorized
    def initialize(message = "E-mail ou senha inválidos")
      super
    end
  end
end
