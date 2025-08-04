# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSources::Json, type: :model do
  describe 'inheritance' do
    it 'inherits from DataSource' do
      expect(described_class.superclass).to eq(DataSource)
    end
  end

  describe '#load_from_file_path' do
    let(:json) { create(:json) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: json) }
    let(:json_content) { '[{"name": "John", "age": 30}, {"name": "Jane", "age": 25}]' }
    let(:file_path) { 'test.json' }

    before do
      allow(File).to receive(:read).with(file_path).and_return(json_content)
    end

    it 'reads the file and processes the JSON content' do
      expect(json).to receive(:process_json).with(json_content).and_call_original
      expect { json.load_from_file_path(file_path) }.to change { json.rows.length }.by(2)
    end
  end

  describe '#load_from_string' do
    let(:json) { create(:json) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: json) }
    let(:json_content) { '[{"name": "John", "age": 30}, {"name": "Jane", "age": 25}]' }

    it 'processes the JSON string directly' do
      expect(json).to receive(:process_json).with(json_content).and_call_original
      expect { json.load_from_string(json_content) }.to change { json.rows.length }.by(2)
    end
  end

  describe '#process_json' do
    let(:json) { create(:json) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: json) }

    it 'handles a JSON array of objects' do
      json_content = '[{"name": "John"}, {"name": "Jane"}]'
      expect { json.send(:process_json, json_content) }.to change {
        json.rows.count
      }.by(2)
      expect(json.rows.first.data['name']).to eq('John')
    end

    it 'handles a single JSON object' do
      json_content = '{"name": "John"}'
      expect { json.send(:process_json, json_content) }.to change {
        json.rows.count
      }.by(1)
      expect(json.rows.first.data['name']).to eq('John')
    end
  end
end
