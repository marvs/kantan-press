# Creates the first admin user. Everything else in Kantan Press comes from a
# WordPress import or from writing posts, so there is nothing else to seed.
#
#   bin/rails db:seed
#   KANTAN_ADMIN_EMAIL=me@example.com KANTAN_ADMIN_PASSWORD=... bin/rails db:seed

email = ENV.fetch("KANTAN_ADMIN_EMAIL", "admin@example.com")
password = ENV["KANTAN_ADMIN_PASSWORD"].presence || SecureRandom.alphanumeric(20)

user = User.find_by(email_address: email)

if user
  puts "Admin user #{email} already exists."
else
  User.create!(email_address: email, password: password, password_confirmation: password)
  puts "Created admin user:"
  puts "  email:    #{email}"
  puts "  password: #{password}"
  puts
  puts "Sign in at /session/new, then visit /admin." unless ENV["KANTAN_ADMIN_PASSWORD"].present?
end
