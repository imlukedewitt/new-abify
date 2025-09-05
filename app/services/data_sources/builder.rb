# frozen_string_literal: true

module DataSources
  # This service is responsible for building a DataSource from a source.
  # It will take a source and a type and return a DataSource.
  # It will also set the name of the DataSource to the original filename if it exists.
  class Builder
    class InvalidSourceError < StandardError; end

    def self.call(source:, type: 'csv')
      unless source.is_a?(ActionDispatch::Http::UploadedFile) || source.is_a?(Rack::Test::UploadedFile)
        raise InvalidSourceError,
              "Source must be a file upload"
      end

      validate_file_type!(source, type)

      "DataSources::#{type.camelize}".constantize.new(source: source).tap do |ds|
        ds.name = File.basename(source.original_filename) if source.respond_to?(:original_filename)
        ds.save!
        ds.load_data
      end
    rescue StandardError => e
      raise InvalidSourceError, e.message
    end

    def self.validate_file_type!(source, type)
      return unless source.respond_to?(:content_type) && source.respond_to?(:original_filename)

      case type.downcase
      when 'csv'
        raise InvalidSourceError, "Unsupported file type" unless valid_csv_file?(source)
      when 'json'
        raise InvalidSourceError, "Unsupported file type" unless valid_json_file?(source)
      else
        raise InvalidSourceError, "Unsupported data source type: #{type}"
      end
    end

    def self.valid_csv_file?(source)
      source.content_type == 'text/csv' || File.extname(source.original_filename).downcase == '.csv'
    end

    def self.valid_json_file?(source)
      source.content_type == 'application/json' || File.extname(source.original_filename).downcase == '.json'
    end
  end
end
