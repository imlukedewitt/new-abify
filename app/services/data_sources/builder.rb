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

      "DataSources::#{type.camelize}".constantize.new(source: source).tap do |ds|
        ds.name = File.basename(source.original_filename) if source.respond_to?(:original_filename)
        ds.save!
        ds.load_data
      end
    rescue StandardError => e
      raise InvalidSourceError, e.message
    end
  end
end
