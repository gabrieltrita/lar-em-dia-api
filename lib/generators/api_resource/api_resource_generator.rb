require "rails/generators"
require "rails/generators/active_record"

class ApiResourceGenerator < Rails::Generators::NamedBase
  include Rails::Generators::Migration

  source_root File.expand_path("templates", __dir__)

  argument :attributes, type: :array, default: [], banner: "field:type field:type"

  SAMPLES = {
    string: %("Example"), text: %("Example text"), integer: "1", float: "1.5", decimal: %("9.99"),
    boolean: "true", date: %("2026-01-01"), datetime: %("2026-01-01T10:00:00Z")
  }.freeze

  OPENAPI_TYPES = {
    integer: "{ type: integer }", float: "{ type: number }", decimal: "{ type: string, format: decimal }",
    boolean: "{ type: boolean }", date: "{ type: string, format: date }", datetime: "{ type: string, format: date-time }"
  }.freeze

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end

  def validate_arguments
    raise Thor::Error, "Namespaced resources are not supported: use a plain name like Product" if class_path.any?
    raise Thor::Error, "Give at least one attribute that is not boolean, for example name:string" if required_attributes.empty?
  end

  def create_migration_file
    migration_template "migration.rb.tt", "db/migrate/create_#{table_name}.rb"
  end

  def create_app_files
    template "model.rb.tt", "app/models/#{file_name}.rb"
    template "policy.rb.tt", "app/policies/#{file_name}_policy.rb"
    template "blueprint.rb.tt", "app/blueprints/#{file_name}_blueprint.rb"
    template "controller.rb.tt", "app/controllers/api/v1/#{plural_file_name}_controller.rb"
  end

  def create_spec_files
    template "factory.rb.tt", "spec/factories/#{plural_file_name}.rb"
    template "model_spec.rb.tt", "spec/models/#{file_name}_spec.rb"
    template "policy_spec.rb.tt", "spec/policies/#{file_name}_policy_spec.rb"
    template "request_spec.rb.tt", "spec/requests/api/v1/#{plural_file_name}_spec.rb"
  end

  def add_route
    append_to_file "config/routes/app.rb", "resources :#{plural_table_name}, only: %i[index show create update destroy]\n"
  end

  def document_in_openapi
    inject_into_file "docs/openapi.yaml", "  - name: #{plural_class_name}\n", before: /^paths:\n/
    inject_into_file "docs/openapi.yaml", template_content("openapi_paths.yml.tt"), before: /^security:\n/
    inject_into_file "docs/openapi.yaml", template_content("openapi_schemas.yml.tt"), before: /^    Pagination:\n/
    inject_into_file "docs/openapi.yaml", template_content("openapi_response.yml.tt"), after: /^  responses:\n/
  end

  def show_next_steps
    say <<~STEPS

      Next steps:
        1. Add `has_many :#{plural_table_name}, dependent: :destroy` to User.
        2. If #{plural_table_name} hold personal data: change those columns to text, add `encrypts` in #{class_name},
           add them to config/initializers/filter_parameter_logging.rb and add :#{plural_table_name} to User::PERSONAL_DATA.
        3. bin/rails db:migrate && bundle exec rspec
    STEPS
  end

  private

  def required_attributes
    attributes.reject { |attribute| attribute.type == :boolean }
  end

  def sample(attribute)
    SAMPLES.fetch(attribute.type, %("Example"))
  end

  def openapi_type(attribute)
    OPENAPI_TYPES.fetch(attribute.type, "{ type: string }")
  end

  def plural_class_name
    class_name.pluralize
  end

  def template_content(source)
    ERB.new(File.read(File.join(self.class.source_root, source)), trim_mode: "-").result(binding)
  end
end
