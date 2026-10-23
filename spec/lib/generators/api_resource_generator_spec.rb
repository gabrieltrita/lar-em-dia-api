require "rails_helper"
require "generators/api_resource/api_resource_generator"

RSpec.describe ApiResourceGenerator do
  let(:root) { Dir.mktmpdir }

  before do
    %w[config/routes/app.rb docs/openapi.yaml].each do |file|
      FileUtils.mkdir_p(File.dirname(File.join(root, file)))
      FileUtils.cp(Rails.root.join(file), File.join(root, file))
    end
  end

  after { FileUtils.remove_entry(root) }

  def generate(*args)
    described_class.new(args, { quiet: true }, destination_root: root).tap { |generator| allow(generator).to receive(:say) }.invoke_all
  end

  def read(file)
    File.read(File.join(root, file))
  end

  context "with a valid resource" do
    before { generate("Product", "name:string", "price:decimal", "active:boolean") }

    it "creates the migration with a uuid key, the owner and the attributes" do
      migration = read(Dir.glob("db/migrate/*_create_products.rb", base: root).sole)

      expect(migration).to include("create_table :products, id: :uuid", "t.references :user, null: false, foreign_key: true, type: :uuid")
      expect(migration).to include("t.string :name, null: false", "t.decimal :price, null: false", "t.boolean :active, null: false, default: false")
      expect(migration).to include("add_index :products, [ :user_id, :created_at ]")
    end

    it "creates the model, policy, blueprint and controller" do
      expect(read("app/models/product.rb")).to include("belongs_to :user", "validates :name, :price, presence: true")
      expect(read("app/policies/product_policy.rb")).to include("class ProductPolicy < ApplicationPolicy", "scope.where(user: user)")
      expect(read("app/blueprints/product_blueprint.rb")).to include("fields :name, :price, :active, :created_at, :updated_at")
      expect(read("app/controllers/api/v1/products_controller.rb")).to include(
        "class ProductsController < ApplicationController", "current_user.products.new(product_params)",
        "policy_scope(Product).find(params[:id])", "params.permit(:name, :price, :active)"
      )
    end

    it "creates the factory and the specs with sample values per type" do
      expect(read("spec/factories/products.rb")).to include('name { "Example" }', 'price { "9.99" }', "active { true }")
      expect(read("spec/models/product_spec.rb")).to include("validate_presence_of(:name)", "validate_presence_of(:price)")
      expect(read("spec/models/product_spec.rb")).not_to include("validate_presence_of(:active)")
      expect(read("spec/policies/product_policy_spec.rb")).to include("RSpec.describe ProductPolicy")
      expect(read("spec/requests/api/v1/products_spec.rb")).to include('name: "Example", price: "9.99", active: true', 'invalid_params) { { name: "" } }')
    end

    it "adds the route to the app's routes file" do
      expect(read("config/routes/app.rb").lines.last).to eq("resources :products, only: %i[index show create update destroy]\n")
    end

    it "documents the resource in OpenAPI" do
      spec = YAML.safe_load(read("docs/openapi.yaml"))

      expect(spec["tags"].map { |tag| tag["name"] }).to include("Products")
      expect(spec["paths"]["/products"].keys).to contain_exactly("get", "post")
      expect(spec["paths"]["/products/{id}"].keys).to contain_exactly("parameters", "get", "patch", "put", "delete")
      expect(spec.dig("components", "schemas", "Product", "properties", "price")).to eq("type" => "string", "format" => "decimal")
      expect(spec.dig("components", "schemas", "Product", "properties", "active")).to eq("type" => "boolean")
      expect(spec.dig("components", "schemas", "ProductInput", "required")).to eq(%w[name price])
      expect(spec.dig("components", "responses", "Product", "content", "application/json", "schema", "properties", "data", "$ref")).to eq("#/components/schemas/Product")
      expect(spec["security"]).to eq([ { "bearerAuth" => [] } ])
    end
  end

  it "maps every supported type to a sample value and an OpenAPI type" do
    generate("Event", "title:string", "notes:text", "seats:integer", "rating:float", "day:date", "starts_at:datetime")

    expect(read("spec/factories/events.rb")).to include('notes { "Example text" }', "seats { 1 }", "rating { 1.5 }", 'day { "2026-01-01" }', 'starts_at { "2026-01-01T10:00:00Z" }')
    properties = YAML.safe_load(read("docs/openapi.yaml")).dig("components", "schemas", "Event", "properties")
    expect(properties.slice("title", "notes", "seats", "rating", "day", "starts_at")).to eq(
      "title" => { "type" => "string" }, "notes" => { "type" => "string" }, "seats" => { "type" => "integer" },
      "rating" => { "type" => "number" }, "day" => { "type" => "string", "format" => "date" },
      "starts_at" => { "type" => "string", "format" => "date-time" }
    )
  end

  it "rejects namespaced names" do
    expect { generate("Shop::Product", "name:string") }.to raise_error(Thor::Error, /Namespaced resources are not supported/)
  end

  it "requires at least one attribute that is not boolean" do
    expect { generate("Flag", "active:boolean") }.to raise_error(Thor::Error, /at least one attribute that is not boolean/)
    expect { generate("Flag") }.to raise_error(Thor::Error, /at least one attribute that is not boolean/)
  end

  it "prints the manual steps" do
    generator = described_class.new([ "Product", "name:string" ], { quiet: true }, destination_root: root)
    allow(generator).to receive(:say)
    generator.invoke_all
    expect(generator).to have_received(:say).with(/has_many :products, dependent: :destroy.*User::PERSONAL_DATA.*db:migrate/m)
  end
end
