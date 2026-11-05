require "rails_helper"
require "rake"

RSpec.describe "categories:seed" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "categories:seed" }
  end

  let(:defaults_count) { Category::DEFAULTS.values.sum(&:size) }

  it "creates the default categories and does not duplicate them on a second run" do
    expect { Rake::Task["categories:seed"].execute }.to change(Category, :count).from(0).to(defaults_count)
    expect { Rake::Task["categories:seed"].execute }.not_to change(Category, :count)
  end

  it "runs after db:prepare" do
    expect(Rake::Task["db:prepare"].actions.size).to be > 1
    Rake::Task["db:prepare"].actions.last.call(Rake::Task["db:prepare"])

    expect(Category.count).to eq(defaults_count)
  end
end
