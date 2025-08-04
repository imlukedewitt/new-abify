# frozen_string_literal: true

require 'json'

module DataSources
  ##
  # JsonData model represents a JSON data source for workflow execution
  class Json < DataSource
    def load_from_file_path(source)
      process_json(File.read(source))
    end

    def load_from_uploaded_file(source)
      process_json(source.read)
    end

    def load_from_string(source)
      process_json(source)
    end

    def load_from_stream(source)
      process_json(source.read)
    end

    private

    def process_json(content)
      json_data = JSON.parse(content)
      rows_data = json_data.is_a?(Array) ? json_data : [json_data]

      rows_data.each_with_index do |row_data, index|
        build_row(row_data, index)
      end

      save_rows!
      self
    end


  end
end
