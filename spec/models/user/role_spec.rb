require 'rails_helper'

RSpec.describe User::Role, type: :model do
  describe 'role enum' do
    it 'defines the correct roles' do
      expect(User.roles).to eq({ 'owner' => 'owner', 'admin' => 'admin', 'member' => 'member', 'system' => 'system' })
    end

    it 'allows setting and querying roles' do
      user = User.new(role: :admin)
      expect(user.admin?).to be true
      expect(user.owner?).to be false
      expect(user.member?).to be false
      expect(user.role).to eq('admin')
    end

    it 'counts owners as admins' do
      user = User.new(role: :owner)
      expect(user.owner?).to be true
      expect(user.admin?).to be true
      expect(user.member?).to be false
    end
  end
end
