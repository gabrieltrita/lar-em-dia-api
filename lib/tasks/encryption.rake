namespace :encryption do
  desc "Re-encrypt every encrypted column with the current primary key (run after adding a new AR_ENCRYPTION_PRIMARY_KEY)"
  task reencrypt: :environment do
    [ User, RefreshToken, AuditLog, Consent ].each do |model|
      count = 0
      model.find_each do |record|
        record.define_singleton_method(:readonly?) { false }
        record.encrypt
        count += 1
      end
      puts "#{model.name}: #{count} re-encrypted"
    end
  end
end
