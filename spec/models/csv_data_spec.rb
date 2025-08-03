# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CsvData, type: :model do
  describe 'inheritance' do
    it 'inherits from DataSource' do
      expect(described_class.superclass).to eq(DataSource)
    end
  end

  describe '#load_from_file_path' do
    let(:csv_data) { create(:csv_data) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv_data) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:file_path) { 'test.csv' }
    let(:options) { { workflow_execution: workflow_execution } }

    before do
      allow(File).to receive(:read).with(file_path).and_return(csv_content)
    end

    it 'reads the file and processes the CSV content' do
      expect(csv_data).to receive(:process_csv).with(csv_content, options).and_call_original
      expect { csv_data.load_from_file_path(file_path, options) }.to change { csv_data.rows.length }.by(2)
    end

    it 'creates rows with the correct data' do
      csv_data.load_from_file_path(file_path, options)

      expect(csv_data.rows.length).to eq(2)
      expect(csv_data.rows.first.data).to eq({ 'name' => 'John', 'age' => '30' })
      expect(csv_data.rows.last.data).to eq({ 'name' => 'Jane', 'age' => '25' })
    end

    it 'raises an error when workflow_execution is not provided' do
      expect { csv_data.load_from_file_path(file_path) }.to raise_error(ArgumentError, 'workflow_execution is required')
    end
  end

  describe '#load_from_uploaded_file' do
    let(:csv_data) { create(:csv_data) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv_data) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:uploaded_file) { double('UploadedFile', read: csv_content) }
    let(:options) { { workflow_execution: workflow_execution } }

    it 'reads the uploaded file and processes the CSV content' do
      expect(csv_data).to receive(:process_csv).with(csv_content, options).and_call_original
      expect { csv_data.load_from_uploaded_file(uploaded_file, options) }.to change { csv_data.rows.length }.by(2)
    end

    it 'raises an error when workflow_execution is not provided' do
      expect do
        csv_data.load_from_uploaded_file(uploaded_file)
      end.to raise_error(ArgumentError, 'workflow_execution is required')
    end
  end

  describe '#load_from_string' do
    let(:csv_data) { create(:csv_data) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv_data) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:options) { { workflow_execution: workflow_execution } }

    it 'processes the CSV string directly' do
      expect(csv_data).to receive(:process_csv).with(csv_content, options).and_call_original
      expect { csv_data.load_from_string(csv_content, options) }.to change { csv_data.rows.length }.by(2)
    end

    it 'raises an error when workflow_execution is not provided' do
      expect { csv_data.load_from_string(csv_content) }.to raise_error(ArgumentError, 'workflow_execution is required')
    end
  end

  describe '#load_from_stream' do
    let(:csv_data) { create(:csv_data) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv_data) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:stream) { StringIO.new(csv_content) }
    let(:options) { { workflow_execution: workflow_execution } }

    it 'reads from the stream and processes the CSV content' do
      expect(csv_data).to receive(:process_csv).with(csv_content, options).and_call_original
      expect { csv_data.load_from_stream(stream, options) }.to change { csv_data.rows.length }.by(2)
    end

    it 'raises an error when workflow_execution is not provided' do
      expect { csv_data.load_from_stream(stream) }.to raise_error(ArgumentError, 'workflow_execution is required')
    end
  end

  describe '#process_csv_from_io' do
    let(:csv_data) { create(:csv_data) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv_data) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:stream) { StringIO.new(csv_content) }
    let(:csv_options) { { headers: true, encoding: 'utf-8', header_converters: ->(h) { h.downcase.strip } } }

    it 'creates rows directly from the IO stream' do
      expect { csv_data.send(:process_csv_from_io, stream, csv_options, workflow_execution) }.to change {
        csv_data.rows.length
      }.by(2)
    end

    it 'sets source_index based on row position' do
      csv_data.send(:process_csv_from_io, stream, csv_options, workflow_execution)

      expect(csv_data.rows.order(:id).first.source_index).to eq(0)
      expect(csv_data.rows.order(:id).last.source_index).to eq(1)
    end

    it 'rewinds the stream after processing' do
      expect(stream).to receive(:rewind).once
      csv_data.send(:process_csv_from_io, stream, csv_options, workflow_execution)
    end
  end

  describe '#process_csv_from_string' do
    let(:csv_data) { create(:csv_data) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv_data) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:csv_options) { { headers: true, encoding: 'utf-8', header_converters: ->(h) { h.downcase.strip } } }

    it 'processes string content and passes to create_rows' do
      expect(csv_data).to receive(:create_rows).with(
        [{ 'name' => 'John', 'age' => '30' }, { 'name' => 'Jane', 'age' => '25' }],
        workflow_execution
      )

      csv_data.send(:process_csv_from_string, csv_content, csv_options, workflow_execution)
    end
  end

  describe '#process_csv' do
    let(:csv_data) { create(:csv_data) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv_data) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:options) { { workflow_execution: workflow_execution } }
    let(:stream) { StringIO.new(csv_content) }

    it 'validates workflow_execution is required' do
      expect do
        csv_data.send(:process_csv, csv_content, {})
      end.to raise_error(ArgumentError, 'workflow_execution is required')
    end

    it 'handles string content by calling process_csv_from_string' do
      expect(csv_data).to receive(:process_csv_from_string).with(csv_content, kind_of(Hash), workflow_execution)
      csv_data.send(:process_csv, csv_content, options)
    end

    it 'handles IO content by calling process_csv_from_io' do
      expect(csv_data).to receive(:process_csv_from_io).with(stream, kind_of(Hash), workflow_execution)
      csv_data.send(:process_csv, stream, options)
    end

    it 'builds CSV options with correct defaults' do
      expected_options = {
        headers: true,
        encoding: 'utf-8',
        header_converters: instance_of(Proc)
      }

      expect(csv_data).to receive(:process_csv_from_string) do |_content, options, workflow_exec|
        expect(options).to include(expected_options)
        expect(workflow_exec).to eq(workflow_execution)
      end

      csv_data.send(:process_csv, csv_content, options)
    end

    it 'includes custom options when provided' do
      custom_options = { col_sep: ';', workflow_execution: workflow_execution }

      expect(csv_data).to receive(:process_csv_from_string) do |_content, options, _workflow_exec|
        expect(options[:headers]).to eq(true)
        expect(options[:col_sep]).to eq(';')
      end

      csv_data.send(:process_csv, csv_content, custom_options)
    end

    context 'when headers have extra spaces and mixed case' do
      let(:csv_content) { " NAME , AGE \nJohn,30\nJane,25" }

      it 'normalizes headers to lowercase and strips whitespace' do
        csv_data.send(:process_csv, csv_content, options)
        expect(csv_data.rows.first.data.keys).to contain_exactly('name', 'age')
      end
    end
  end

  describe '#create_rows' do
    let(:csv_data) { create(:csv_data) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv_data) }
    let(:rows_data) { [{ 'name' => 'John', 'age' => '30' }, { 'name' => 'Jane', 'age' => '25' }] }

    it 'creates a row for each data item' do
      expect { csv_data.send(:create_rows, rows_data, workflow_execution) }.to change { csv_data.rows.length }.by(2)
    end

    it 'sets the correct data for each row' do
      csv_data.send(:create_rows, rows_data, workflow_execution)

      expect(csv_data.rows.first.data).to eq({ 'name' => 'John', 'age' => '30' })
      expect(csv_data.rows.last.data).to eq({ 'name' => 'Jane', 'age' => '25' })
    end

    it 'associates rows with the workflow execution' do
      csv_data.send(:create_rows, rows_data, workflow_execution)

      expect(csv_data.rows.all? { |row| row.workflow_execution_id == workflow_execution.id }).to be true
    end

    it 'sets source_index based on position when not provided' do
      csv_data.send(:create_rows, rows_data, workflow_execution)

      expect(csv_data.rows.order(:id).first.source_index).to eq(0)
      expect(csv_data.rows.order(:id).last.source_index).to eq(1)
    end

    it 'uses provided source_index when available' do
      rows_with_source_index = [
        { 'name' => 'John', 'age' => '30', 'source_index' => 100 },
        { 'name' => 'Jane', 'age' => '25', source_index: 200 }
      ]

      csv_data.send(:create_rows, rows_with_source_index, workflow_execution)

      expect(csv_data.rows.order(:id).first.source_index).to eq(100)
      expect(csv_data.rows.order(:id).last.source_index).to eq(200)
    end

    it 'removes source_index from the data hash' do
      rows_with_source_index = [
        { 'name' => 'John', 'age' => '30', 'source_index' => 100 }
      ]

      csv_data.send(:create_rows, rows_with_source_index, workflow_execution)

      expect(csv_data.rows.first.data).not_to have_key('source_index')
    end
  end
end
