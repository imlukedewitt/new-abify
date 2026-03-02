# frozen_string_literal: true

module ConnectionSlot
  module Normalizer
    class << self
      # Normalizes connection slots from various input formats into a consistent array of hashes.
      # @param raw_slots [Hash, Array, ActionController::Parameters] The input data
      # @return [Array<Hash>] Normalized slots with string keys
      def call(raw_slots)
        coerce_to_array(raw_slots)
          .map { |slot_params| normalize_item(slot_params) }
          .compact
      end

      private

      def normalize_item(params)
        # Ensure we're working with a Hash and indifferent keys
        slot = params.respond_to?(:to_h) ? params.to_h.with_indifferent_access : nil

        return nil unless slot.is_a?(Hash) && slot[:handle].present?

        result = {
          'handle' => slot[:handle].to_s.strip,
          'description' => slot[:description].to_s.strip,
          'default' => cast_boolean(slot[:default])
        }

        # Match the sparse hash format expected by existing specs
        result.delete('description') if result['description'].blank?
        result.delete('default') unless result['default']

        result
      end

      def coerce_to_array(slots)
        case slots
        when ActionController::Parameters, Hash
          slots.values
        when Array
          slots
        else
          []
        end
      end

      def cast_boolean(value)
        # Standard Rails boolean casting: '1', 'true', true => true. Everything else => false.
        ActiveModel::Type::Boolean.new.cast(value) == true
      end
    end
  end
end
