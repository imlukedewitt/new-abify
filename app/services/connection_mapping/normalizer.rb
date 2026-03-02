# frozen_string_literal: true

module ConnectionMapping
  ##
  # Normalizes and enriches connection mappings with audit data (name, handle)
  class Normalizer
    class << self
      ##
      # @param workflow [Workflow]
      # @param raw_mappings [Hash, ActionController::Parameters]
      # @return [Hash] Enriched mappings with connection_id, connection_name, and connection_handle
      def call(workflow:, raw_mappings:)
        return {} if raw_mappings.blank?

        # Use the existing Resolver to find the actual connections
        resolver = ConnectionSlot::Resolver.new(
          workflow: workflow,
          connection_mappings: raw_mappings
        )
        resolution = resolver.call

        # We don't fail here; we just return what we can resolve.
        # The model validator will handle the error reporting if things are missing.
        enrich_mappings(raw_mappings, resolution[:connections])
      end

      private

      def enrich_mappings(raw_mappings, resolved_connections)
        enriched = {}

        raw_mappings.each do |slot_handle, metadata|
          connection = resolved_connections[slot_handle]

          enriched[slot_handle] = if connection
                                    {
                                      'connection_id' => connection.id.to_s,
                                      'connection_name' => connection.name,
                                      'connection_handle' => connection.handle
                                    }
                                  else
                                    # Keep raw metadata if we can't resolve it,
                                    # so validator can report specific errors
                                    metadata
                                  end
        end

        enriched
      end
    end
  end
end
