module Auth
  class InvalidToken < Unauthorized
    def initialize(message = "Token inválido ou expirado")
      super
    end
  end
end
