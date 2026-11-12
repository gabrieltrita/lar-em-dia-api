module MarketData
  class Download
    HTTP_TIMEOUT = 10
    MAX_BYTES = 30.megabytes
    MAX_ENTRY_BYTES = 100.megabytes
    FETCH_ERRORS = [
      Unavailable, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, Zip::Error
    ].freeze

    def self.zip_entries(uri, names)
      new(uri).zip_entries(names)
    end

    def initialize(uri)
      @uri = uri
    end

    def zip_entries(names)
      body = fetch
      body && extract(body, names)
    rescue *FETCH_ERRORS => e
      Rails.logger.warn({ message: "Market data download failed", host: @uri.host, error: e.class.name })
      raise Unavailable
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
      raise Unavailable if entry.nil? || entry.size > MAX_ENTRY_BYTES

      entry.get_input_stream { |stream| stream.read(MAX_ENTRY_BYTES + 1) }.tap do |content|
        raise Unavailable if content.bytesize > MAX_ENTRY_BYTES
      end
    end
  end
end
