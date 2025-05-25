# frozen_string_literal: true

require_relative 'filters/workflow_filters'
require_relative '../../../lib/data_utils'

module Liquid
  # Processor class for Liquid templates
  class Processor
    def initialize(template_string, context_data = {})
      @template_string = template_string
      @context_data = context_data
      @environment = create_liquid_environment
    end

    def render
      template = Liquid::Template.parse(@template_string, environment: @environment)
      template.render(DataUtils.deep_stringify_keys(@context_data))
    end

    def render_as_boolean
      result = render
      DataUtils.to_boolean(result)
    end

    def valid?
      Liquid::Template.parse(@template_string, environment: @environment)
      true
    rescue Liquid::SyntaxError
      false
    end

    def validation_errors
      Liquid::Template.parse(@template_string, environment: @environment)
      nil
    rescue Liquid::SyntaxError => e
      e.message
    end

    private

    def create_liquid_environment
      environment = Liquid::Environment.new
      environment.register_filter(WorkflowFilters)
      environment
    end
  end
end
