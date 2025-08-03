# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSource, type: :model do
  def mock_source(type_name, positive_class)
    source = double(type_name)
    setup_type_stubs(source, positive_class)
    source
  end

  def setup_type_stubs(source, positive_class)
    classes = [
      String,
      ActionDispatch::Http::UploadedFile,
      Rack::Test::UploadedFile,
      Hash,
      ActionController::Parameters,
      IO,
      StringIO
    ]

    classes.each do |klass|
      allow(source).to receive(:is_a?).with(klass).and_return(klass == positive_class)
    end
  end

  describe 'factories' do
    it 'has a valid default factory' do
      data_source = build(:data_source)
      expect(data_source).to be_valid
    end

    it 'has a valid csv factory trait' do
      data_source = build(:data_source, :csv)
      expect(data_source).to be_valid
      expect(data_source.type).to eq('DataSources::Csv')
    end

    it 'has a valid json factory trait' do
      data_source = build(:data_source, :json)
      expect(data_source).to be_valid
      expect(data_source.type).to eq('DataSources::Json')
    end

    it 'has a valid mock factory trait' do
      data_source = build(:data_source, :mock)
      expect(data_source).to be_valid
      expect(data_source.type).to eq('MockData')
    end
  end

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
      data_source = build(:data_source, name: 'Test Source', type: 'DataSources::Csv')
      expect(data_source).to be_valid
    end
  end

  describe 'constants' do
    it 'defines SOURCE_TYPES constant' do
      expect(described_class::SOURCE_TYPES).to eq(%w[
        file_path
        json_string
        string
        uploaded_file
        payload
        stream
      ].freeze)
    end
  end

  describe '#load_data' do
    let(:data_source) { build(:data_source) }
    let(:source) { 'test_source' }
    let(:options) { { option: 'value' } }

    it 'determines source type and calls appropriate load method' do
      expect(data_source).to receive(:determine_source_type).with(source).and_return('string')
      expect(data_source).to receive(:load_from_string).with(source, options)

      data_source.load_data(source, options)
    end
  end

  describe '#determine_source_type' do
    let(:data_source) { build(:data_source) }

    context 'when source is a String' do
      it 'delegates to determine_string_source_type' do
        source = 'test_string'
        expect(data_source).to receive(:determine_string_source_type).with(source).and_return('string')

        expect(data_source.send(:determine_source_type, source)).to eq('string')
      end
    end

    context 'when source is an uploaded file' do
      it 'returns uploaded_file for ActionDispatch::Http::UploadedFile' do
        source = mock_source('ActionDispatch::Http::UploadedFile', ActionDispatch::Http::UploadedFile)
        expect(data_source.send(:determine_source_type, source)).to eq('uploaded_file')
      end

      it 'returns uploaded_file for Rack::Test::UploadedFile' do
        source = mock_source('Rack::Test::UploadedFile', Rack::Test::UploadedFile)
        expect(data_source.send(:determine_source_type, source)).to eq('uploaded_file')
      end
    end

    context 'when source is a Hash or Parameters' do
      it 'returns payload for Hash' do
        source = { key: 'value' }

        expect(data_source.send(:determine_source_type, source)).to eq('payload')
      end

      it 'returns payload for ActionController::Parameters' do
        source = mock_source('ActionController::Parameters', ActionController::Parameters)
        expect(data_source.send(:determine_source_type, source)).to eq('payload')
      end
    end

    context 'when source is a stream' do
      it 'returns stream for IO object' do
        source = mock_source('IO', IO)
        expect(data_source.send(:determine_source_type, source)).to eq('stream')
      end

      it 'returns stream for StringIO object' do
        source = mock_source('StringIO', StringIO)
        expect(data_source.send(:determine_source_type, source)).to eq('stream')
      end
    end

    context 'when source is unsupported' do
      it 'raises ArgumentError' do
        source = Object.new

        expect { data_source.send(:determine_source_type, source) }.to raise_error(
          ArgumentError, "Unsupported source type: #{source.class}"
        )
      end
    end
  end

  describe '#determine_string_source_type' do
    let(:data_source) { build(:data_source) }

    context 'when string is a file path' do
      it 'returns file_path when file exists' do
        allow(File).to receive(:exist?).and_return(true)
        source = 'path/to/file.csv'

        expect(data_source.send(:determine_string_source_type, source)).to eq('file_path')
      end

      it 'returns file_path when string starts with /' do
        source = '/absolute/path/to/file.csv'

        expect(data_source.send(:determine_string_source_type, source)).to eq('file_path')
      end
    end

    context 'when string is a JSON string' do
      it 'returns json_string for JSON object string' do
        source = '{ "key": "value" }'

        expect(data_source.send(:determine_string_source_type, source)).to eq('json_string')
      end

      it 'returns json_string for JSON array string' do
        source = '[ {"key": "value"} ]'

        expect(data_source.send(:determine_string_source_type, source)).to eq('json_string')
      end
    end

    context 'when string is a regular string' do
      it 'returns string for any other string' do
        source = 'just a regular string'

        expect(data_source.send(:determine_string_source_type, source)).to eq('string')
      end
    end
  end

  describe 'dynamically defined load methods' do
    let(:data_source) { build(:data_source) }
    let(:source) { 'test_source' }
    let(:options) { { option: 'value' } }

    described_class::SOURCE_TYPES.each do |source_type|
      it "raises NotImplementedError for load_from_#{source_type}" do
        expect { data_source.send("load_from_#{source_type}", source, options) }.to raise_error(
          NotImplementedError, "Loading from #{source_type} is not implemented"
        )
      end
    end
  end
end
