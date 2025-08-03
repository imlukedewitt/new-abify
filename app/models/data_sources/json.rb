# frozen_string_literal: true

require 'json'

module DataSources
  ##
  # JsonData model represents a JSON data source for workflow execution
  class Json < DataSource
    def load_from_file_path(source, options = {})
      process_json(File.read(source), options)
    end

    def load_from_uploaded_file(source, options = {})
      process_json(source.read, options)
    end

    def load_from_string(source, options = {})
      process_json(source, options)
    end

    def load_from_stream(source, options = {})
      process_json(source.read, options)
    end

    private

    def process_json(content, options = {})
      workflow_execution = options[:workflow_execution]
      raise ArgumentError, 'workflow_execution is required' unless workflow_execution

      json_data = JSON.parse(content)
      rows_data = json_data.is_a?(Array) ? json_data : [json_data]

      create_rows(rows_data, workflow_execution)

      self
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
end
