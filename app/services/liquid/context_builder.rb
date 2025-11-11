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
        row: { "source_index" => @row.source_index, **@row.data }
      }.merge(connection_info)
    end

    private

    def connection_info
      return unless @workflow.connection

      {
        'subdomain' => @workflow.connection.subdomain,
        'domain' => @workflow.connection.domain,
        'base_url' => @workflow.connection.base_url
      }
    end
  end
end
