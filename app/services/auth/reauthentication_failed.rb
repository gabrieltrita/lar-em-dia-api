module Auth
  class ReauthenticationFailed < StandardError
    attr_reader :code

    def initialize(message = "Reauthentication failed", code: "reauthentication_failed")
      super(message)
      @code = code
    end
  end
end
