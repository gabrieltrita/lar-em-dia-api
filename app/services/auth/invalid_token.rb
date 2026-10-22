module Auth
  class InvalidToken < Unauthorized
    def initialize(message = "Invalid or expired token", code: "invalid_token")
      super
    end
  end
end
