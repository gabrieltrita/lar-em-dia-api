module Auth
  class InvalidCredentials < Unauthorized
    def initialize(message = "Invalid email or password", code: "invalid_credentials")
      super
    end
  end
end
