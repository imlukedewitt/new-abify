# frozen_string_literal: true

require 'liquid'
require_relative 'hydra_manager'
require_relative 'liquid/processor'
require_relative 'liquid/context_builder'

# StepProcessor is responsible for processing a workflow step
class StepProcessor
  attr_reader :step, :row, :config

  def initialize(step, row, hydra_manager: HydraManager.instance, on_complete: nil, api_key: nil)
    raise ArgumentError, 'step is required' unless step
    raise ArgumentError, 'row is required' unless row

    @step = step
    @row = row
    @config = @step.config.with_indifferent_access
    @hydra_manager = hydra_manager
    @on_complete = on_complete
    @api_key = api_key
  end

  def self.call(step, row)
    new(step, row).call
  end

  def call
    @hydra_manager.queue(
      **render_request_fields,
      api_key: @api_key,
      on_complete: lambda { |response|
        result = process_response(response)
        @on_complete&.call(result)
      }
    )
  end

  def should_skip?
    evaluate_boolean_condition('skip_condition')
  end

  def required?
    evaluate_boolean_condition('required_condition')
  end

  private

  def process_response(response)
    return { success: false, error: "No response received" } if response.nil?

    parsed_response = parse_json_response(response.body)

    if response.status.between?(200, 299)
      success_data = extract_success_data(parsed_response)
      { success: true, data: success_data }
    else
      error = parsed_response["errors"] || "Request failed with status #{response.status}"
      { success: false, error: error }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def parse_json_response(body)
    return {} if body.nil? || body.empty?

    JSON.parse(body)
  rescue JSON::ParserError
    body.to_s
  end

  def extract_success_data(parsed_response)
    success_templates = @config.dig('liquid_templates', 'success_data')
    return {} unless success_templates.is_a?(Hash)

    context_with_response = context.merge('response' => parsed_response)

    success_templates.each_with_object({}) do |(key, template), result|
      processor = Liquid::Processor.new(template, context_with_response)
      result[key] = processor.render
    rescue StandardError => e
      raise "Failed to extract required success data '#{key}': #{e.message}" if required?
    end
  end

  def evaluate_boolean_condition(condition_key)
    condition = @config.dig('liquid_templates', condition_key)
    return false unless condition

    processor = Liquid::Processor.new(condition, context)
    processor.render_as_boolean
  end

  def render_template_field(field_name)
    template = @config.dig('liquid_templates', field_name)
    return nil unless template

    processor = Liquid::Processor.new(template, context)
    processor.render
  end

  def context
    @context ||= Liquid::ContextBuilder.new(
      row: @row,
      workflow: @step.workflow
    ).build
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
