# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSources::Csv, type: :model do
  describe 'inheritance' do
    it 'inherits from DataSource' do
      expect(described_class.superclass).to eq(DataSource)
    end
  end

  describe '#load_from_file_path' do
    let(:csv) { create(:csv) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:file_path) { 'test.csv' }

    before do
      allow(File).to receive(:read).with(file_path).and_return(csv_content)
    end

    it 'reads the file and processes the CSV content' do
      expect(csv).to receive(:process_csv).with(csv_content).and_call_original
      expect { csv.load_from_file_path(file_path) }.to change { csv.rows.length }.by(2)
    end

    it 'creates rows with the correct data' do
      csv.load_from_file_path(file_path)

      expect(csv.rows.length).to eq(2)
      expect(csv.rows.first.data).to eq({ 'name' => 'John', 'age' => '30' })
      expect(csv.rows.last.data).to eq({ 'name' => 'Jane', 'age' => '25' })
    end
  end

  describe '#load_from_uploaded_file' do
    let(:csv) { create(:csv) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:uploaded_file) { double('UploadedFile', read: csv_content) }

    it 'reads the uploaded file and processes the CSV content' do
      expect(csv).to receive(:process_csv).with(csv_content).and_call_original
      expect { csv.load_from_uploaded_file(uploaded_file) }.to change { csv.rows.length }.by(2)
    end
  end

  describe '#load_from_string' do
    let(:csv) { create(:csv) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }

    it 'processes the CSV string directly' do
      expect(csv).to receive(:process_csv).with(csv_content).and_call_original
      expect { csv.load_from_string(csv_content) }.to change { csv.rows.length }.by(2)
    end
  end

  describe '#load_from_stream' do
    let(:csv) { create(:csv) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:stream) { StringIO.new(csv_content) }

    it 'reads from the stream and processes the CSV content' do
      expect(csv).to receive(:process_csv).with(csv_content).and_call_original
      expect { csv.load_from_stream(stream) }.to change { csv.rows.length }.by(2)
    end
  end

  describe '#process_csv_from_io' do
    let(:csv) { create(:csv) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:stream) { StringIO.new(csv_content) }

    it 'creates rows directly from the IO stream' do
      expect { csv.send(:process_csv_from_io, stream) }.to change {
        csv.rows.length
      }.by(2)
    end

    it 'sets source_index based on row position' do
      csv.send(:process_csv_from_io, stream)
      csv.rows.each(&:save!)

      expect(csv.rows.order(:source_index).first.source_index).to eq(1)
      expect(csv.rows.order(:source_index).last.source_index).to eq(2)
    end

    it 'rewinds the stream after processing' do
      expect(stream).to receive(:rewind).once
      csv.send(:process_csv_from_io, stream)
    end
  end

  describe '#process_csv_from_string' do
    let(:csv) { create(:csv) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }

    it 'builds rows from CSV content' do
      expect(csv).to receive(:build_row).with({ 'name' => 'John', 'age' => '30' }, 1).ordered
      expect(csv).to receive(:build_row).with({ 'name' => 'Jane', 'age' => '25' }, 2).ordered

      csv.send(:process_csv_from_string, csv_content)
    end
  end

  describe '#process_csv' do
    let(:csv) { create(:csv) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv) }
    let(:csv_content) { "name,age\nJohn,30\nJane,25" }
    let(:stream) { StringIO.new(csv_content) }

    it 'handles string content by calling process_csv_from_string' do
      expect(csv).to receive(:process_csv_from_string).with(csv_content)
      csv.send(:process_csv, csv_content)
    end

    it 'handles IO content by calling process_csv_from_io' do
      expect(csv).to receive(:process_csv_from_io).with(stream)
      csv.send(:process_csv, stream)
    end
  end

  describe '#build_row' do
    let(:csv) { create(:csv) }
    let(:workflow) { create(:workflow) }
    let(:workflow_execution) { create(:workflow_execution, workflow: workflow, data_source: csv) }
    let(:row_data) { { 'name' => 'John', 'age' => '30' } }

    it 'builds a row with the provided data' do
      expect { csv.send(:build_row, row_data, 1) }.to change { csv.rows.length }.by(1)
      expect(csv.rows.last).to be_new_record
    end

    it 'sets the correct data for the row' do
      csv.send(:build_row, row_data, 1)
      expect(csv.rows.last.data).to eq({ 'name' => 'John', 'age' => '30' })
    end

    it 'sets source_index from the provided default_index' do
      csv.send(:build_row, row_data, 42)
      expect(csv.rows.last.source_index).to eq(42)
    end

    it 'uses provided source_index when available' do
      row_with_source_index = { 'name' => 'John', 'age' => '30', 'source_index' => 100 }
      csv.send(:build_row, row_with_source_index, 1)
      expect(csv.rows.last.source_index).to eq(100)
    end

    it 'handles source_index as a symbol' do
      row_with_source_index = { 'name' => 'John', 'age' => '30', source_index: 200 }
      csv.send(:build_row, row_with_source_index, 1)
      expect(csv.rows.last.source_index).to eq(200)
    end

    it 'removes source_index from the data hash' do
      row_with_source_index = { 'name' => 'John', 'age' => '30', 'source_index' => 100 }
      csv.send(:build_row, row_with_source_index, 1)
      expect(csv.rows.last.data).not_to have_key('source_index')
    end
  end

  describe '#save_rows!' do
    let(:csv) { create(:csv) }

    it 'saves all built rows' do
      row1 = csv.rows.build(data: { 'name' => 'John' }, source_index: 1)
      row2 = csv.rows.build(data: { 'name' => 'Jane' }, source_index: 2)

      expect(row1).to be_new_record
      expect(row2).to be_new_record

      csv.send(:save_rows!)

      expect(row1).not_to be_new_record
      expect(row2).not_to be_new_record
    end

    it 'only saves new records' do
      # Create a persisted row
      persisted_row = csv.rows.create!(data: { 'name' => 'Existing' }, source_index: 0)

      # Build a new row
      new_row = csv.rows.build(data: { 'name' => 'New' }, source_index: 1)

      # Only the new_row should receive save!
      expect(persisted_row).not_to receive(:save!)
      expect(new_row).to receive(:save!).once

      csv.send(:save_rows!)
    end
  end
end
