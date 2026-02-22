# frozen_string_literal: true

##
# Validates connection_mappings JSON structure and content
# Expects connection_mappings to be a hash mapping slot handles to connection metadata
class ConnectionMappingsValidator
  attr_reader :connection_mappings, :errors

  REQUIRED_METADATA_KEYS = %w[connection_id connection_name connection_handle].freeze

  def initialize(connection_mappings)
    @connection_mappings = connection_mappings
    @errors = []
  end

  def valid?
    validate
    errors.empty?
  end

  def validate
    @errors = []

    return true if connection_mappings.nil?

    unless connection_mappings.is_a?(Hash)
      errors << 'must be a hash'
      return false
    end

    connection_mappings.each do |slot_handle, metadata|
      validate_mapping(slot_handle, metadata)
    end

    errors.empty?
  end

  private

  def validate_mapping(slot_handle, metadata)
    unless metadata.is_a?(Hash)
      errors << "mapping for '#{slot_handle}' must be a hash"
      return
    end

    REQUIRED_METADATA_KEYS.each do |key|
      errors << "mapping for '#{slot_handle}' is missing required key: #{key}" unless metadata.key?(key)
    end
  end
end
