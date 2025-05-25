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
        row: @row.data,
        **connection_info
      }
    end

    private

    def connection_info
      config = @workflow.config || {}
      subdomain = config.dig('connection', 'subdomain') || 'acme'
      domain = config.dig('connection', 'domain') || 'application.com'

      {
        subdomain: subdomain,
        domain: domain,
        base_url: "https://#{subdomain}.#{domain}"
      }
    end
  end
end
