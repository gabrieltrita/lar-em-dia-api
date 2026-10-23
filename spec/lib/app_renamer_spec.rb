require "rails_helper"

RSpec.describe AppRenamer do
  let(:root) { Dir.mktmpdir }
  let(:old) { Rails.configuration.x.app }
  let(:old_module) { "#{old.slug.capitalize}Api" }
  let(:files) { [ described_class::IDENTITY_FILE, described_class::APPLICATION_FILE, described_class::COMPOSE_FILE, *described_class::DOCUMENTS ] }
  let(:embedded_slug) { /(?<=[a-z.])#{old.slug}|#{old.slug}(?=[a-z])/ }

  before do
    files.each do |file|
      FileUtils.mkdir_p(File.dirname(File.join(root, file)))
      FileUtils.cp(Rails.root.join(file), File.join(root, file))
    end
  end

  after { FileUtils.remove_entry(root) }

  def read(file)
    File.read(File.join(root, file))
  end

  def rename(slug, **options)
    described_class.new(root: root, slug: slug, **options).call
  end

  def snapshot
    files.to_h { |file| [ file, read(file) ] }
  end

  it "renames config, compose and docs from the slug and returns the manual steps" do
    expect(rename("zetaapp")).to eq(described_class::MANUAL_STEPS)

    expect(YAML.safe_load(read("config/app.yml"))).to eq("shared" => { "name" => "Zetaapp", "slug" => "zetaapp", "domain" => "zetaapp.dev" })
    expect(read("config/application.rb")).to include("module ZetaappApi")
    expect(read("docker-compose.yml")).to start_with("name: zetaapp\n").and include("image: zetaapp-api:dev")
    expect(read("README.md")).to start_with("# zetaapp-api\n").and include("the Zetaapp apps", "**zetaapp-web**", "`zetaapp_refresh`", "`zetaapp_api_development`", "`zetaapp.dev`")
    expect(read("docs/openapi.yaml")).to include("title: zetaapp-api", "`zetaapp_refresh` for this app")
    expect(read(".claude/CLAUDE.md")).to include("`ZetaappApi` module name")
  end

  it "leaves no trace of the old identity in the docs but keeps words that merely contain the slug" do
    embedded_before = described_class::DOCUMENTS.to_h { |file| [ file, read(file).scan(embedded_slug).size ] }
    rename("zetaapp")

    described_class::DOCUMENTS.each do |file|
      text = read(file)
      expect(text).not_to match(/(?<![a-z.])#{old.slug}(?![a-z])/), file
      expect(text).not_to match(/\b#{Regexp.escape(old.name)}\b/), file
      expect(text).not_to include(old.domain, old_module)
      expect(text.scan(embedded_slug).size).to eq(embedded_before[file]), file
    end
  end

  it "uses a custom name and domain" do
    rename("minhaloja", name: "Minha Loja: Centro", domain: "minhaloja.com.br")

    expect(YAML.safe_load(read("config/app.yml")).dig("shared", "name")).to eq("Minha Loja: Centro")
    expect(read("README.md")).to include("`minhaloja.com.br`", "the Minha Loja: Centro apps")
    expect(read("README.md")).not_to include("minhaloja.dev")
  end

  it "renames an app that was already renamed" do
    rename("zetaapp")
    rename("omegaapp")

    expect(read("config/application.rb")).to include("module OmegaappApi")
    expect(read("README.md")).to start_with("# omegaapp-api\n")
    expect(read("README.md")).not_to include("zetaapp")
  end

  context "with invalid input" do
    it "rejects a slug with anything but lowercase letters and digits" do
      %w[Acme my_app my-app 1acme].each do |slug|
        expect { rename(slug) }.to raise_error(described_class::Error, /Slug must start with a letter/)
      end
    end

    it "rejects an invalid domain" do
      expect { rename("zetaapp", domain: "not a domain") }.to raise_error(described_class::Error, /Domain must look like/)
    end

    it "rejects renaming to the current slug" do
      expect { rename(old.slug) }.to raise_error(described_class::Error, "The app is already named #{old.slug}")
    end

    it "lists missing files" do
      FileUtils.rm(File.join(root, "docs/SECURITY.md"))
      expect { rename("zetaapp") }.to raise_error(described_class::Error, "Missing files: docs/SECURITY.md")
    end

    it "does not touch any file when validation fails" do
      before_files = snapshot
      expect { rename("Bad") }.to raise_error(described_class::Error)
      expect(snapshot).to eq(before_files)
    end
  end
end
