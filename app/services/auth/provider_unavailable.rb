module Auth
  class ProviderUnavailable < StandardError
    def initialize(message = "The identity provider is unavailable")
      super
    end
  end
end
