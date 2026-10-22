module Auth
  # Base dos erros de autenticação (viram HTTP 401 em ErrorHandling).
  class Unauthorized < StandardError
    def initialize(message = "Não autorizado")
      super
    end
  end
end
