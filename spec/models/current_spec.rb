# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Current, type: :model do
  after do
    Current.reset
  end

  describe '.user' do
    it 'can be read and set' do
      user = build(:user)
      Current.user = user
      expect(Current.user).to eq(user)
    end
  end
end
