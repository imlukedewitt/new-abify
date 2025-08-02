# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSource, type: :model do
  # Factory tests
  describe 'factories' do
    it 'has a valid default factory' do
      data_source = build(:data_source)
      expect(data_source).to be_valid
    end

    it 'has a valid csv factory trait' do
      data_source = build(:data_source, :csv)
      expect(data_source).to be_valid
      expect(data_source.type).to eq('CsvData')
    end

    it 'has a valid json factory trait' do
      data_source = build(:data_source, :json)
      expect(data_source).to be_valid
      expect(data_source.type).to eq('JsonData')
    end

    it 'has a valid mock factory trait' do
      data_source = build(:data_source, :mock)
      expect(data_source).to be_valid
      expect(data_source.type).to eq('MockData')
    end
  end

  # Association tests
  describe 'associations' do
    it 'has many rows' do
      association = described_class.reflect_on_association(:rows)
      expect(association.macro).to eq(:has_many)
    end

    it 'has many workflow_executions' do
      association = described_class.reflect_on_association(:workflow_executions)
      expect(association.macro).to eq(:has_many)
    end

    it 'can be associated with rows' do
      data_source = create(:data_source)
      workflow_execution = create(:workflow_execution, data_source: data_source)
      row = create(:row, data_source: data_source, workflow_execution: workflow_execution)

      expect(data_source.rows).to include(row)
    end

    it 'can be associated with workflow_executions' do
      data_source = create(:data_source)
      workflow_execution = create(:workflow_execution, data_source: data_source)

      expect(data_source.workflow_executions).to include(workflow_execution)
    end
  end

  # Validation tests
  describe 'validations' do
    it 'validates presence of name' do
      data_source = build(:data_source, name: nil)
      expect(data_source).not_to be_valid
      expect(data_source.errors[:name]).to include("can't be blank")
    end

    it 'validates presence of type' do
      data_source = build(:data_source, type: nil)
      expect(data_source).not_to be_valid
      expect(data_source.errors[:type]).to include("can't be blank")
    end

    it 'is valid with name and type' do
      data_source = build(:data_source, name: 'Test Source', type: 'CsvData')
      expect(data_source).to be_valid
    end
  end
end
