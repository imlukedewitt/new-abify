# frozen_string_literal: true

require 'csv'

##
# CsvData model represents a CSV data source for workflow execution
class CsvData < DataSource
  def load_from_file_path(source, options = {})
    process_csv(File.read(source), options)
  end

  def load_from_uploaded_file(source, options = {})
    process_csv(source.read, options)
  end

  def load_from_string(source, options = {})
    process_csv(source, options)
  end

  def load_from_stream(source, options = {})
    process_csv(source.read, options)
  end

  private

  def process_csv(content, options = {})
    workflow_execution = options[:workflow_execution]
    raise ArgumentError, 'workflow_execution is required' unless workflow_execution

    csv_options = {
      headers: true,
      encoding: 'utf-8',
      header_converters: ->(h) { h.downcase.strip }
    }

    csv_options[:col_sep] = options[:col_sep] if options[:col_sep].present?

    if content.is_a?(IO) || content.is_a?(StringIO)
      process_csv_from_io(content, csv_options, workflow_execution)
    else
      process_csv_from_string(content, csv_options, workflow_execution)
    end

    self
  end

  def process_csv_from_io(io, csv_options, workflow_execution)
    index = 0
    csv_enum = CSV.new(io, **csv_options)

    csv_enum.each do |csv_row|
      row_data = csv_row.to_h
      rows.create!(data: row_data, workflow_execution: workflow_execution, source_index: index)
      index += 1
    end

    io.rewind if io.respond_to?(:rewind)
  end

  def process_csv_from_string(content, csv_options, workflow_execution)
    index = 0
    rows_data = []

    CSV.parse(content, **csv_options).each do |csv_row|
      row_data = csv_row.to_h
      rows_data << row_data
      index += 1
    end

    create_rows(rows_data, workflow_execution)
  end

  def create_rows(rows_data, workflow_execution)
    rows_data.each_with_index do |row_data, index|
      source_index = index

      if row_data.is_a?(Hash) && (row_data.key?('source_index') || row_data.key?(:source_index))
        source_index = row_data['source_index'] || row_data[:source_index]

        row_data = row_data.dup
        row_data.delete('source_index')
        row_data.delete(:source_index)
      end

      rows.create!(
        data: row_data,
        workflow_execution: workflow_execution,
        source_index: source_index
      )
    end
  end
end
