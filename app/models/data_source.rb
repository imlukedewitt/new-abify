# frozen_string_literal: true

##
# DataSource model represents a source of data for a workflow execution
# This could be a CSV file, JSON data, API response, etc.
class DataSource < ApplicationRecord
  has_many :rows
  has_many :workflow_executions

  validates :name, presence: true
  validates :type, presence: true

  SOURCE_TYPES = %w[
    file_path
    json_string
    string
    uploaded_file
    payload
    stream
  ].freeze

  def load_data(source, options = {})
    source_type = determine_source_type(source)
    send("load_from_#{source_type}", source, options)
  end

  SOURCE_TYPES.each do |source_type|
    define_method("load_from_#{source_type}") do |_source, _options|
      raise NotImplementedError, "Loading from #{source_type} is not implemented"
    end
  end

  private

  def determine_source_type(source)
    return determine_string_source_type(source) if source.is_a?(String)
    return 'uploaded_file' if uploaded_file?(source)
    return 'payload' if payload?(source)
    return 'stream' if stream?(source)

    raise ArgumentError, "Unsupported source type: #{source.class}"
  end

  def uploaded_file?(source)
    source.is_a?(ActionDispatch::Http::UploadedFile) || source.is_a?(Rack::Test::UploadedFile)
  end

  def payload?(source)
    source.is_a?(Hash) || source.is_a?(ActionController::Parameters)
  end

  def stream?(source)
    source.is_a?(IO) || source.is_a?(StringIO)
  end

  def determine_string_source_type(source)
    if File.exist?(source) || source.start_with?('/')
      'file_path'
    elsif source.match?(/\A\s*\{.*\}\s*\z/m) || source.match?(/\A\s*\[.*\]\s*\z/m)
      'json_string'
    else
      'string'
    end
  end
end
