namespace :categories do
  desc "Create the default categories that are missing (idempotent, also runs after db:prepare)"
  task seed: :environment do
    Category.seed_defaults!
  end
end

Rake::Task["db:prepare"].enhance { Rake::Task["categories:seed"].invoke }
