require "rails_helper"

RSpec.describe MarketData::Download do
  let(:url) { "https://dados.cvm.gov.br/dados/sample.zip" }
  let(:uri) { URI(url) }

  before { allow(Rails.logger).to receive(:warn) }

  it "returns the requested entries of a ZIP file" do
    stub_request(:get, url).to_return(body: zip_of("a.csv" => "first", "b.csv" => "second", "c.csv" => "third"))

    expect(described_class.zip_entries(uri, %w[a.csv c.csv])).to eq("a.csv" => "first", "c.csv" => "third")
  end

  it "returns nil when the file does not exist yet" do
    stub_request(:get, url).to_return(status: 404)

    expect(described_class.zip_entries(uri, %w[a.csv])).to be_nil
  end

  it "fails when an entry is missing" do
    stub_request(:get, url).to_return(body: zip_of("a.csv" => "first"))

    expect { described_class.zip_entries(uri, %w[b.csv]) }.to raise_error(MarketData::Unavailable)
    expect(Rails.logger).to have_received(:warn)
      .with({ message: "Market data download failed", host: "dados.cvm.gov.br", error: "MarketData::Unavailable" })
  end

  it "fails on an error status" do
    stub_request(:get, url).to_return(status: 503)

    expect { described_class.zip_entries(uri, %w[a.csv]) }.to raise_error(MarketData::Unavailable)
  end

  it "fails on network errors and logs only the exception class" do
    stub_request(:get, url).to_timeout

    expect { described_class.zip_entries(uri, %w[a.csv]) }.to raise_error(MarketData::Unavailable)
    expect(Rails.logger).to have_received(:warn).with(hash_including(error: "Net::OpenTimeout"))
  end

  it "fails when the body is not a ZIP file" do
    stub_request(:get, url).to_return(body: "<html>maintenance</html>")

    expect { described_class.zip_entries(uri, %w[a.csv]) }.to raise_error(MarketData::Unavailable)
    expect(Rails.logger).to have_received(:warn).with(hash_including(error: "Zip::Error"))
  end

  it "fails when the download is larger than the limit" do
    stub_const("#{described_class}::MAX_BYTES", 10)
    stub_request(:get, url).to_return(body: "x" * 11)

    expect { described_class.zip_entries(uri, %w[a.csv]) }.to raise_error(MarketData::Unavailable)
  end

  it "fails when an entry declares more than the limit" do
    stub_const("#{described_class}::MAX_ENTRY_BYTES", 4)
    stub_request(:get, url).to_return(body: zip_of("a.csv" => "first"))

    expect { described_class.zip_entries(uri, %w[a.csv]) }.to raise_error(MarketData::Unavailable)
  end

  it "fails when an entry inflates beyond the limit despite its declared size" do
    stub_request(:get, url).to_return(body: zip_of("a.csv" => "first"))
    entry = instance_double(Zip::Entry, size: 1)
    allow(entry).to receive(:get_input_stream).and_yield(StringIO.new("x" * 5))
    allow(Zip::File).to receive(:open_buffer).and_return(instance_double(Zip::File, find_entry: entry))
    stub_const("#{described_class}::MAX_ENTRY_BYTES", 4)

    expect { described_class.zip_entries(uri, %w[a.csv]) }.to raise_error(MarketData::Unavailable)
  end

  describe ".zip_lines" do
    it "yields the lines of an entry" do
      stub_request(:get, url).to_return(body: zip_of("a.txt" => "one\ntwo\n"))
      lines = []

      expect(described_class.zip_lines(uri, "a.txt") { |line| lines << line }).to be(true)
      expect(lines).to eq([ "one\n", "two\n" ])
    end

    it "returns nil when the file does not exist yet" do
      stub_request(:get, url).to_return(status: 404)

      expect(described_class.zip_lines(uri, "a.txt") { |_line| nil }).to be_nil
    end

    it "fails when the entry is missing or the source is down" do
      stub_request(:get, url).to_return(body: zip_of("a.txt" => "one"))
      expect { described_class.zip_lines(uri, "b.txt") { |_line| nil } }.to raise_error(MarketData::Unavailable)

      stub_request(:get, url).to_return(status: 500)
      expect { described_class.zip_lines(uri, "a.txt") { |_line| nil } }.to raise_error(MarketData::Unavailable)
    end

    it "stops when the lines inflate beyond the limit despite the declared size" do
      stub_request(:get, url).to_return(body: zip_of("a.txt" => "one"))
      entry = instance_double(Zip::Entry, size: 1)
      allow(entry).to receive(:get_input_stream).and_yield(StringIO.new("12\n34\n"))
      allow(Zip::File).to receive(:open_buffer).and_return(instance_double(Zip::File, find_entry: entry))
      stub_const("#{described_class}::MAX_ENTRY_BYTES", 4)
      lines = []

      expect { described_class.zip_lines(uri, "a.txt") { |line| lines << line } }.to raise_error(MarketData::Unavailable)
      expect(lines).to eq([ "12\n" ])
    end
  end
  describe ".zip_entry_lines" do
    it "yields the lines of several entries with their names, in order" do
      stub_request(:get, url).to_return(body: zip_of("a.csv" => "one\ntwo\n", "b.csv" => "three\n", "c.csv" => "skipped\n"))
      lines = []

      expect(described_class.zip_entry_lines(uri, %w[b.csv a.csv]) { |name, line| lines << [ name, line ] }).to be(true)
      expect(lines).to eq([ [ "b.csv", "three\n" ], [ "a.csv", "one\n" ], [ "a.csv", "two\n" ] ])
    end

    it "returns nil when the file does not exist yet" do
      stub_request(:get, url).to_return(status: 404)

      expect(described_class.zip_entry_lines(uri, %w[a.csv]) { |_name, _line| nil }).to be_nil
    end

    it "fails when an entry is missing" do
      stub_request(:get, url).to_return(body: zip_of("a.csv" => "one"))

      expect { described_class.zip_entry_lines(uri, %w[a.csv b.csv]) { |_name, _line| nil } }.to raise_error(MarketData::Unavailable)
    end
  end
end
