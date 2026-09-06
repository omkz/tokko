if Rails.env.development?
  load Rails.root.join("db/seeds/development.rb")
else
  puts "No default seed data for this environment."
end
