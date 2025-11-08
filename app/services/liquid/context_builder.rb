# frozen_string_literal: true

module Liquid
  # builds context for liquid templates with row/api info
  class ContextBuilder
    def initialize(row:, workflow:)
      @row = row
      @workflow = workflow
    end

    def build
      {
        row: { "source_index" => @row.source_index, **@row.data },
        connection: connection_info
      }
    end

    private

    def connection_info
      # Use actual Connection model if available
      if @workflow.connection
        return {
          'subdomain' => @workflow.connection.subdomain,
          'domain' => @workflow.connection.domain,
          'base_url' => @workflow.connection.base_url
        }
      end

      # Fallback to config-based connection (for backward compatibility)
      config = @workflow.workflow_config || {}
      subdomain = config.dig('connection', 'subdomain')
      domain = config.dig('connection', 'domain')

      return {} if subdomain.nil? || domain.nil?

      {
        'subdomain' => subdomain,
        'domain' => domain,
        'base_url' => "https://#{subdomain}.#{domain}"
      }
    end
  end
end
