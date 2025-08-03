# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Row, type: :model do
  describe 'associations' do
    it 'has many step_executions' do
      association = described_class.reflect_on_association(:step_executions)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :destroy
    end
  end

  describe 'callbacks' do
    context 'after_initialize' do
      let(:initial_data) { { 'name' => 'John Doe', 'details' => { 'age' => 30 } } }
      let(:row) { build(:row, data: initial_data) }

      it 'sets original_data with a deep copy of data for a new record' do
        expect(row.original_data).to eq(initial_data)
      end

      it 'does not set original_data for a persisted record' do
        row.save!
        row.data['name'] = 'Jane Doe'
        persisted_row = Row.find(row.id)
        expect(persisted_row.original_data).to eq(initial_data)
      end

      it 'ensures original_data is a distinct object from data' do
        expect(row.original_data).not_to be(row.data)
      end

      it 'modifying data does not affect original_data' do
        row.data['name'] = 'Jane Doe'
        row.data['details']['age'] = 31
        expect(row.original_data['name']).to eq('John Doe')
        expect(row.original_data['details']['age']).to eq(30)
      end
    end
  end
end
