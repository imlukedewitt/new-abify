require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'callbacks' do
    it 'sets api_token for new records' do
      user = build(:user)
      expect(user.api_token).to be_present
      expect(user.api_token).to be_a(String)
      expect(user.api_token.length).to eq(40)
    end
  end

  describe 'validations' do
    let(:token) { 'the_token' }
    let!(:user) { create(:user, api_token: token) }
    let(:user2) { build(:user, api_token: token) }
    it 'validates api_token is unique' do
      expect(user2).not_to be_valid
      expect(user2.errors[:api_token]).to include('has already been taken')
    end
  end
end
