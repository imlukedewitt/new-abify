# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts 'Creating system user...'
system_user = User.find_or_create_by!(email: 'system@app.local') do |user|
  user.first_name = 'System'
  user.last_name = 'User'
  user.role = 'system'
  user.api_token = 'api_key'
end
puts "✓ System user created (ID: #{system_user.id})"
