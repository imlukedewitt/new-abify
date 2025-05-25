# frozen_string_literal: true

require 'liquid'
require_relative 'liquid_processor'

##
# StepProcessor is responsible for processing a workflow step
class StepProcessor
  attr_reader :step, :row, :config

  def initialize(step, row)
    raise ArgumentError, 'step is required' unless step
    raise ArgumentError, 'row is required' unless row

    @step = step
    @row = row
    @config = @step.config.with_indifferent_access
  end

  def self.call(step, row)
    new(step, row).call
  end

  def call
    # .
  end

  private

  def context
    @context ||= {
      row: @row.data
    }
  end

  def should_skip?
    skip_condition = @config['skip_condition']
    return false unless skip_condition

    processor = LiquidProcessor.new(skip_condition, context)
    processor.render_as_boolean
  end

  def render_template_field(field_name)
    template = @config.dig('liquid_templates', field_name)
    return nil unless template

    processor = LiquidProcessor.new(template, context)
    processor.render
  end

  def render_request_fields
    liquid_templates = @config['liquid_templates']
    return {} unless liquid_templates.is_a?(Hash)

    result = {}

    %w[url method body params].each do |field|
      rendered_value = render_template_field(field)
      result[field.to_sym] = rendered_value if rendered_value
    end

    result
  end
end
