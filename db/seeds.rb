# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts 'Creating system user...'
system_user = User.find_or_create_by!(email: 'system@app.local') do |user|
  user.first_name = 'System'
  user.last_name = 'User'
  user.role = 'system'
  user.api_token = 'api_key_system'
end
puts "✓ System user created (ID: #{system_user.id})"

puts 'Creating owner user...'
owner_user = User.find_or_create_by!(email: 'owner@app.local') do |user|
  user.first_name = 'Owner'
  user.last_name = 'User'
  user.role = 'owner'
  user.api_token = 'api_token_owner'
end
puts "✓ Owner user created (ID: #{owner_user.id})"

puts 'Creating admin user...'
admin_user = User.find_or_create_by!(email: 'admin@app.local') do |user|
  user.first_name = 'Admin'
  user.last_name = 'User'
  user.role = 'admin'
  user.api_token = 'api_token_admin'
end
puts "✓ Admin user created (ID: #{admin_user.id})"

puts 'Creating member user...'
member_user = User.find_or_create_by!(email: 'member@app.local') do |user|
  user.first_name = 'Member'
  user.last_name = 'User'
  user.role = 'member'
  user.api_token = 'api_token_member'
end
puts "✓ Member user created (ID: #{member_user.id})"
