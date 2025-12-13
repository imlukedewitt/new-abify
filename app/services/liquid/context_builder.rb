# frozen_string_literal: true

module Liquid
  # builds context for liquid templates with row/api info
  class ContextBuilder
    def initialize(row:, workflow:, row_execution: nil)
      @row = row
      @workflow = workflow
      @row_execution = row_execution
    end

    def build
      {
        row: {
          "source_index" => @row.source_index,
          **@row.data,
          **accumulated_success_data
        }
      }.merge(connection_info)
    end

    private

    def accumulated_success_data
      return {} unless @row_execution

      @row_execution.merged_success_data
    end

    def connection_info
      return {} unless @workflow.connection

      {
        'subdomain' => @workflow.connection.subdomain,
        'domain' => @workflow.connection.domain,
        'base_url' => @workflow.connection.base_url
      }
    end
  end
end
