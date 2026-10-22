module Auth
  class Unauthorized < StandardError
    attr_reader :code

    def initialize(message = "Unauthorized", code: "unauthorized")
      super(message)
      @code = code
    end
  end
end
