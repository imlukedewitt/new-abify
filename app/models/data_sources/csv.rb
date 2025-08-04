# frozen_string_literal: true

require 'csv'

module DataSources
  ##
  # CsvData model represents a CSV data source for workflow execution
  class Csv < DataSource
    def load_from_file_path(source)
      process_csv(File.read(source))
    end

    def load_from_uploaded_file(source)
      process_csv(source.read)
    end

    def load_from_string(source)
      process_csv(source)
    end

    def load_from_stream(source)
      process_csv(source.read)
    end

    private

    def process_csv(content)
      if content.is_a?(IO) || content.is_a?(StringIO)
        process_csv_from_io(content)
      else
        process_csv_from_string(content)
      end

      save_rows!
      self
    end

    def process_csv_from_io(io)
      index = 1
      CSV.new(
        io,
        headers: true,
        header_converters: ->(h) { h.downcase.strip },
        encoding: 'utf-8'
      ).each do |csv_row|
        row_data = csv_row.to_h
        build_row(row_data, index)
        index += 1
      end

      io.rewind if io.respond_to?(:rewind)
    end

    def process_csv_from_string(content)
      index = 1

      CSV.parse(
        content.strip,
        headers: true,
        header_converters: ->(h) { h.downcase.strip },
        encoding: 'utf-8'
      ).each do |csv_row|
        build_row(csv_row.to_h, index)
        index += 1
      end
    end
  end
end
