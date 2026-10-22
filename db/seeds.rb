# Cria o admin inicial a partir das variáveis ADMIN_EMAIL / ADMIN_PASSWORD.
# Idempotente: pode rodar várias vezes.
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@trita.dev")
admin_password = ENV.fetch("ADMIN_PASSWORD") { raise "Defina ADMIN_PASSWORD para rodar o seed" }

admin = User.find_or_initialize_by(email: admin_email)
if admin.new_record?
  admin.assign_attributes(first_name: "Admin", last_name: "Trita", password: admin_password, role: :admin)
  admin.save!
  puts "Admin criado: #{admin_email}"
else
  puts "Admin já existe: #{admin_email}"
end

if Rails.env.development? && User.user.count.zero?
  User.create!(email: "user@trita.dev", first_name: "Usuário", last_name: "Teste", password: "User@123456", role: :user)
  puts "Usuário de teste criado: user@trita.dev / User@123456"
end
