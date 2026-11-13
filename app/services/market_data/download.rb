module MarketData
  class Download
    HTTP_TIMEOUT = 10
    MAX_BYTES = 30.megabytes
    MAX_ENTRY_BYTES = 100.megabytes
    FETCH_ERRORS = [
      Unavailable, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, Zip::Error, JSON::ParserError
    ].freeze

    def self.zip_entries(uri, names)
      new(uri).zip_entries(names)
    end

    def self.zip_lines(uri, name, &)
      new(uri).zip_lines(name, &)
    end

    def self.zip_entry_lines(uri, names, &)
      new(uri).zip_entry_lines(names, &)
    end

    def self.json(uri)
      new(uri).json
    end

    def initialize(uri)
      @uri = uri
    end

    def json
      body = fetch
      body && JSON.parse(body)
    rescue *FETCH_ERRORS => e
      fail_with(e)
    end

    def zip_entries(names)
      body = fetch
      body && extract(body, names)
    rescue *FETCH_ERRORS => e
      fail_with(e)
    end

    def zip_lines(name, &)
      body = fetch
      body && each_line(Zip::File.open_buffer(StringIO.new(body)).find_entry(name), &)
    rescue *FETCH_ERRORS => e
      fail_with(e)
    end

    def zip_entry_lines(names)
      body = fetch
      return unless body

      zip = Zip::File.open_buffer(StringIO.new(body))
      names.each { |name| each_line(zip.find_entry(name)) { |line| yield name, line } }
      true
    rescue *FETCH_ERRORS => e
      fail_with(e)
    end

    private

    def fetch
      Net::HTTP.start(@uri.host, @uri.port, use_ssl: true, open_timeout: HTTP_TIMEOUT, read_timeout: HTTP_TIMEOUT) do |http|
        http.request(Net::HTTP::Get.new(@uri)) do |response|
          return nil if response.is_a?(Net::HTTPNotFound)
          raise Unavailable unless response.is_a?(Net::HTTPSuccess)

          return read_limited(response)
        end
      end
    end

    def read_limited(response)
      body = +""
      response.read_body do |chunk|
        body << chunk
        raise Unavailable if body.bytesize > MAX_BYTES
      end
      body
    end

    def extract(body, names)
      zip = Zip::File.open_buffer(StringIO.new(body))
      names.index_with { |name| read_entry(zip.find_entry(name)) }
    end

    def read_entry(entry)
      check_entry(entry)
      entry.get_input_stream { |stream| stream.read(MAX_ENTRY_BYTES + 1) }.tap do |content|
        raise Unavailable if content.bytesize > MAX_ENTRY_BYTES
      end
    end

    def each_line(entry)
      check_entry(entry)
      read = 0
      entry.get_input_stream do |stream|
        stream.each_line do |line|
          read += line.bytesize
          raise Unavailable if read > MAX_ENTRY_BYTES

          yield line
        end
      end
      true
    end

    def check_entry(entry)
      raise Unavailable if entry.nil? || entry.size > MAX_ENTRY_BYTES
    end

    def fail_with(error)
      Rails.logger.warn({ message: "Market data download failed", host: @uri.host, error: error.class.name })
      raise Unavailable
    end
  end
end
