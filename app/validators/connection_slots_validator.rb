# frozen_string_literal: true

##
# Validates connection_slots JSON structure and content
# Expects connection_slots to be an array of slot objects
class ConnectionSlotsValidator
  attr_reader :connection_slots, :errors

  def initialize(connection_slots)
    @connection_slots = connection_slots
    @errors = []
  end

  def valid?
    validate
    errors.empty?
  end

  def validate
    @errors = []

    return true if connection_slots.nil?

    unless connection_slots.is_a?(Array)
      errors << 'connection_slots must be an array'
      return false
    end

    validate_slot_structures
    validate_slot_handles

    errors.empty?
  end

  private

  def validate_slot_structures
    connection_slots.each_with_index do |slot, index|
      unless slot.is_a?(Hash)
        errors << "slot at index #{index} must be a hash"
        next
      end

      unless slot.key?('handle')
        errors << "slot at index #{index} must have a 'handle' key"
        next
      end

      validate_slot_handle_format(slot['handle'], index)
      validate_slot_optional_keys(slot, index)
    end
  end

  def validate_slot_handles
    handles = connection_slots.filter_map { |slot| slot['handle'] if slot.is_a?(Hash) }
    duplicate_handles = handles.group_by { |h| h }.select { |_, group| group.size > 1 }.keys

    duplicate_handles.each do |handle|
      errors << "slot handle '#{handle}' is duplicated"
    end
  end

  def validate_slot_handle_format(handle, index)
    return if handle =~ Workflow::HANDLE_FORMAT

    errors << "slot at index #{index} handle '#{handle}' must start with a letter and contain only lowercase letters, numbers, hyphens, and underscores"
  end

  def validate_slot_optional_keys(slot, index)
    slot.each_key do |key|
      next if %w[handle description default].include?(key)

      errors << "slot at index #{index} has unexpected key '#{key}' (allowed: handle, description, default)"
    end

    if slot.key?('description') && !slot['description'].is_a?(String)
      errors << "slot at index #{index} description must be a string"
    end

    return unless slot.key?('default') && ![true, false].include?(slot['default'])

    errors << "slot at index #{index} default must be a boolean"
  end
end
