require "rails_helper"

RSpec.describe JsonLogFormatter do
  let(:time) { Time.zone.parse("2026-10-23 13:40:12.345") }

  def format(message, severity: "INFO")
    line = described_class.new.call(severity, time, nil, message)
    expect(line).to end_with("\n")
    JSON.parse(line)
  end

  it "merges structured events, such as lograge request lines" do
    expect(format({ method: "GET", path: "/api/v1/notes", status: 200 })).to eq(
      "time" => "2026-10-23T16:40:12.345Z", "level" => "INFO", "method" => "GET", "path" => "/api/v1/notes", "status" => 200
    )
  end

  it "wraps plain text in a message field" do
    expect(format("Job enqueued", severity: "DEBUG")).to eq("time" => "2026-10-23T16:40:12.345Z", "level" => "DEBUG", "message" => "Job enqueued")
  end

  it "logs only the class of an exception, never its message" do
    entry = format(ActiveRecord::RecordNotFound.new("Couldn't find User with email=someone@example.com"), severity: "ERROR")

    expect(entry).to eq("time" => "2026-10-23T16:40:12.345Z", "level" => "ERROR", "error" => "ActiveRecord::RecordNotFound")
    expect(entry.to_json).not_to include("someone@example.com")
  end
end
