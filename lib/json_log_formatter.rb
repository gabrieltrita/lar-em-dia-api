require "json"
require "logger"

class JsonLogFormatter < ::Logger::Formatter
  def call(severity, time, _progname, message)
    "#{{ time: time.utc.iso8601(3), level: severity }.merge(fields(message)).to_json}\n"
  end

  private

  def fields(message)
    case message
    when Hash then message
    when Exception then { error: message.class.name }
    else { message: message.to_s }
    end
  end
end
