# frozen_string_literal: true

require_relative 'environment'
require_relative '../../../lib/data_utils'

module Liquid
  # Pre-parses and renders workflow-level Liquid templates
  # Parses all templates on initialization for validation and performance
  class WorkflowTemplates
    def initialize(liquid_templates)
      @liquid_templates = liquid_templates || {}
      @environment = EnvironmentBuilder.build
      @group_by = parse(@liquid_templates['group_by'])
      @sort_by = parse(@liquid_templates['sort_by'])
    end

    # Renders the group_by template with context
    # @param context [Hash] The Liquid context with row data
    # @return [String, nil] The rendered group key
    def group_key(context)
      render(@group_by, context)
    end

    # Renders the sort_by template with context
    # @param context [Hash] The Liquid context with row data
    # @return [String, nil] The rendered sort value
    def sort_key(context)
      render(@sort_by, context)
    end

    private

    def parse(template_string)
      return nil unless template_string.is_a?(String) && !template_string.empty?

      ::Liquid::Template.parse(template_string, environment: @environment)
    end

    def render(template, context)
      return nil unless template

      stringify_context = DataUtils.deep_stringify_keys(context)
      template.render(stringify_context)
    end
  end
end
