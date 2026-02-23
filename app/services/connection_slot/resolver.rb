# frozen_string_literal: true

module ConnectionSlot
  ##
  # Resolves abstract connection slots to concrete connections
  class Resolver
    attr_reader :workflow, :connection_mappings, :errors, :connections

    ##
    # @param workflow [Workflow]
    # @param connection_mappings [Hash] mapping of slot handles to connection metadata
    def initialize(workflow:, connection_mappings:)
      raise ArgumentError, 'workflow is required' if workflow.nil?
      raise ArgumentError, 'connection_mappings is required' if connection_mappings.nil?

      @workflow = workflow
      @connection_mappings = connection_mappings
      @errors = []
      @connections = {}
    end

    ##
    # Executes the resolution logic
    # @return [Hash] { connections: { handle => Connection }, errors: [String] }
    def call
      Rails.logger.info "Resolving connection slots for Workflow #{workflow.id}"
      validate_mappings
      resolve_connections

      if errors.any?
        Rails.logger.error "Connection resolution failed for Workflow #{workflow.id}: #{errors.join(', ')}"
      else
        Rails.logger.info "Successfully resolved #{connections.size} connections for Workflow #{workflow.id}"
      end

      {
        connections: connections,
        errors: errors
      }
    end

    private

    def validate_mappings
      workflow_slots = workflow.connection_slots || []
      workflow_handles = workflow_slots.map { |s| s['handle'] }

      # Check for missing mappings for workflow slots
      workflow_handles.each do |handle|
        next if connection_mappings.key?(handle)

        errors << "Missing mapping for slot '#{handle}'"
      end

      # Check for mappings that don't exist in the workflow
      connection_mappings.each_key do |handle|
        next if workflow_handles.include?(handle)

        errors << "Mapping references a slot '#{handle}' that does not exist in the workflow"
      end
    end

    def resolve_connections
      workflow_handles = workflow.connection_slots&.map { |s| s['handle'] } || []

      connection_ids = connection_mappings.values.map { |m| m['connection_id'] }.compact
      db_connections = Connection.where(user: Current.user, id: connection_ids).index_by(&:id)

      connection_mappings.each do |handle, metadata|
        connection_id = metadata['connection_id']
        connection = db_connections[connection_id.to_i]

        if connection.nil?
          errors << "Connection for slot '#{handle}' not found"
          next
        end

        connections[handle] = connection
      end
    end
  end
end
