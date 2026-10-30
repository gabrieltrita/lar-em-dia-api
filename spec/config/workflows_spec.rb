require "rails_helper"

RSpec.describe "GitHub workflows" do
  def load_yaml(path)
    YAML.safe_load(Rails.root.join(path).read, aliases: false)
  end

  let(:ci) { load_yaml(".github/workflows/ci.yml") }
  let(:deploy) { load_yaml(".github/workflows/deploy.yml") }
  let(:action) { load_yaml(".github/actions/kamal-deploy/action.yml") }
  let(:jobs) { deploy.fetch("jobs") }
  let(:kamal_config) { Rails.root.join("config/deploy.yml").read }
  let(:variables_read_by_kamal) { kamal_config.scan(/ENV\.fetch\("([A-Z_]+)"/).flatten.uniq }
  let(:production_secrets) { Rails.root.join(".kamal/secrets").read.lines.filter_map { |line| line[/\A([A-Z_]+)=/, 1] } - [ "KAMAL_REGISTRY_PASSWORD" ] }
  let(:staging_secrets) { production_secrets.map { |name| "STAGING_#{name}" } }

  def steps_of(workflow_or_action)
    jobs = workflow_or_action["jobs"]&.values || [ workflow_or_action["runs"] ]
    jobs.flat_map { |job| job["steps"].to_a }
  end

  it "runs the CI before every deploy and keeps the CI reusable" do
    expect(ci.fetch("on", ci[true])).to include("workflow_call", "pull_request")
    expect(ci.fetch("on", ci[true]).dig("push", "branches")).to eq([ "dev" ])
    expect(jobs["ci"]["uses"]).to eq("./.github/workflows/ci.yml")
    expect(jobs.values_at("staging", "production").map { |job| job["needs"] }).to all(eq("ci"))
  end

  it "deploys staging from main and production only from a version tag on main" do
    on = deploy.fetch("on", deploy[true])
    expect(on["push"]["branches"]).to eq([ "main" ])
    expect(on["push"]["tags"]).to eq([ "[0-9]+.[0-9]+.[0-9]+" ])
    expect(jobs["staging"]["if"]).to include("github.ref_type == 'branch'")
    expect(jobs["production"]["if"]).to include("github.ref_type == 'tag'")
    expect(jobs["production"]["steps"].map { |step| step["run"] }).to include('git merge-base --is-ancestor "$GITHUB_SHA" origin/main')
  end

  it "does not deploy where no server is configured" do
    expect(jobs["staging"]["if"]).to include("vars.STAGING_DEPLOY_HOST != ''")
    expect(jobs["production"]["if"]).to include("vars.DEPLOY_HOST != ''")
  end

  it "gives each job every variable and secret the Kamal configuration reads" do
    production_env = jobs["production"]["env"].keys
    staging_env = jobs["staging"]["env"].keys

    expect(variables_read_by_kamal - production_env).to be_empty
    expect(variables_read_by_kamal - staging_env).to be_empty
    expect(production_secrets - production_env).to be_empty
    expect(staging_secrets - staging_env).to be_empty
  end

  it "keeps staging and production values apart" do
    staging_values = jobs["staging"]["env"].values.map(&:to_s)
    production_values = jobs["production"]["env"].values.map(&:to_s)

    expect(production_values.grep(/STAGING_/)).to be_empty
    expect(staging_values.grep(/(secrets|vars)\.(?!STAGING_|GITHUB_TOKEN)/)).to be_empty
    expect(jobs["staging"]["steps"].last["with"].values.join).not_to match(/secrets\.(?!STAGING_)/)
    expect(jobs["production"]["steps"].last["with"].values.join).not_to include("STAGING_")
  end

  it "publishes images with the workflow token and the least permissions" do
    expect(deploy["permissions"]).to eq({ "contents" => "read" })
    expect(jobs.values_at("staging", "production").map { |job| job["permissions"] }).to all(eq({ "contents" => "read", "packages" => "write" }))
    expect(jobs["staging"]["env"]["KAMAL_REGISTRY_PASSWORD"]).to eq("${{ secrets.GITHUB_TOKEN }}")
    expect(jobs["production"]["env"]["KAMAL_REGISTRY_PASSWORD"]).to eq("${{ secrets.GITHUB_TOKEN }}")
  end

  it "never runs two deploys of the same environment at once or cancels one midway" do
    expect(jobs["staging"]["concurrency"]).to eq({ "group" => "deploy-staging", "cancel-in-progress" => false })
    expect(jobs["production"]["concurrency"]).to eq({ "group" => "deploy-production", "cancel-in-progress" => false })
  end

  it "passes the SSH key and the known hosts to the action as data, never inside a script" do
    all_steps = steps_of(ci) + steps_of(deploy) + steps_of(action)
    scripts = all_steps.filter_map { |step| step["run"] }

    expect(scripts).not_to be_empty
    expect(scripts.grep(/\$\{\{/)).to be_empty
    expect(action.dig("runs", "steps").find { |step| step["name"] == "Configure SSH" }["env"].keys).to contain_exactly("SSH_PRIVATE_KEY", "SSH_KNOWN_HOSTS")
    expect(action.dig("runs", "steps").map { |step| step["run"].to_s }.join).to include("StrictHostKeyChecking yes")
  end

  it "only uses actions from GitHub, Docker, Ruby or this repository" do
    used = (steps_of(ci) + steps_of(deploy) + steps_of(action)).filter_map { |step| step["uses"] }

    expect(used).not_to be_empty
    expect(used).to all(match(%r{\A(actions|docker|ruby)/|\A\./}))
  end
end
