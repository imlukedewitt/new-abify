# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Row, type: :model do
  describe 'associations' do
    it 'has many step_executions' do
      association = described_class.reflect_on_association(:step_executions)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :destroy
    end

    it 'has many row_executions' do
      association = described_class.reflect_on_association(:row_executions)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :destroy
    end
  end
end
