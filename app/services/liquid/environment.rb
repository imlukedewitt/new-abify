# frozen_string_literal: true

require_relative 'filters/workflow_filters'

module Liquid
  # Shared Liquid environment configuration with custom filters
  module EnvironmentBuilder
    def self.build
      env = ::Liquid::Environment.new
      env.register_filter(WorkflowFilters)
      env
    end
  end
end
