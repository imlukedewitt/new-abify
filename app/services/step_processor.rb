# frozen_string_literal: true

require 'liquid'
require_relative 'hydra_manager'
require_relative 'liquid_processor'

# StepProcessor is responsible for processing a workflow step
class StepProcessor
  attr_reader :step, :row, :config

  def initialize(step, row)
    raise ArgumentError, 'step is required' unless step
    raise ArgumentError, 'row is required' unless row

    @step = step
    @row = row
    @config = @step.config.with_indifferent_access
    @hydra_manager = HydraManager.instance
  end

  def self.call(step, row)
    new(step, row).call
  end

  def call
    # TODO: where does the API key come from?
    url, method, body, params = render_request_fields.values_at(:url, :method, :body, :params)
    @hydra_manager.queue(
      url: url,
      method: method,
      body: body,
      params: params
    )
  end

  private

  # TODO: Should this be a public method? Or maybe even a class method?
  # the RowProcessor needs to know this info before calling the StepProcessor
  def should_skip?
    evaluate_boolean_condition('skip_condition')
  end

  # TODO: same as above
  def required?
    evaluate_boolean_condition('required_condition')
  end

  def evaluate_boolean_condition(condition_key)
    condition = @config.dig('liquid_templates', condition_key)
    return false unless condition

    processor = LiquidProcessor.new(condition, context)
    processor.render_as_boolean
  end

  def render_template_field(field_name)
    template = @config.dig('liquid_templates', field_name)
    return nil unless template

    processor = LiquidProcessor.new(template, context)
    processor.render
  end

  # TODO: should this live elsewhere?
  def context
    # TODO: temporary stubbing subdomain and domain. this should be configured at the workflow execution level?
    subdomain = 'acme'
    domain = 'application.com'
    @context ||= {
      row: @row.data,
      subdomain: subdomain,
      domain: domain,
      base_url: "https://#{subdomain}.#{domain}"
    }
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
