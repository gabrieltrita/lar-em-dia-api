require "rails_helper"

RSpec.describe "Kamal deploy configuration" do
  let(:app) { YAML.load_file(Rails.root.join("config/app.yml")).fetch("shared") }
  let(:raw) { Rails.root.join("config/deploy.yml").read }
  let(:secrets_lines) { Rails.root.join(".kamal/secrets").read.lines.map(&:strip).reject(&:empty?) }
  let(:environment) do
    {
      "KAMAL_REGISTRY_USERNAME" => "Octo",
      "DEPLOY_HOST" => "203.0.113.10",
      "APP_HOST" => "api.example.com",
      "CORS_ORIGINS" => "https://app.example.com",
      "FRONTEND_URL" => "https://app.example.com",
      "MAILER_FROM" => "App <no-reply@example.com>",
      "SMTP_ADDRESS" => "smtp.example.com"
    }
  end
  let(:config) do
    originals = environment.keys.index_with { |key| ENV[key] }
    environment.each { |key, value| ENV[key] = value }
    Dir.chdir(Rails.root) { YAML.safe_load(ERB.new(raw).result) }
  ensure
    originals.each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
  end

  def delivered_variables
    config.dig("env", "clear").keys + config.dig("env", "secret")
  end

  it "names the service and the image after config/app.yml and nothing else" do
    expect(config["service"]).to eq("#{app['slug']}-api")
    expect(config["image"]).to eq("octo/#{app['slug']}-api")
    [ app["name"], app["slug"], app["domain"] ].each { |identity| expect(raw).not_to include(identity) }
  end

  it "delivers every variable the app requires to boot in production" do
    expect(EnvValidator::REQUIRED - delivered_variables).to be_empty
  end

  it "runs Sidekiq as its own role and publishes no database or Redis port" do
    expect(config.dig("servers", "job", "cmd")).to eq("bundle exec sidekiq -C config/sidekiq.yml")
    expect(config["accessories"].values.map { |accessory| accessory["port"] }).to all(be_nil)
  end

  it "keeps a reference in .kamal/secrets for every secret and no value" do
    needed = config.dig("env", "secret") +
      config["accessories"].values.flat_map { |accessory| accessory.dig("env", "secret").to_a } +
      config.dig("registry", "password")

    expect(secrets_lines.map { |line| line.split("=").first }).to match_array(needed)
    expect(secrets_lines).to all(match(/\A([A-Z_]+)=(\$\1|\$\{\1:-\})\z/))
  end

  it "serializes empty optional values as strings" do
    expect(config.dig("env", "clear", "GOOGLE_CLIENT_IDS")).to eq("")
  end
end
