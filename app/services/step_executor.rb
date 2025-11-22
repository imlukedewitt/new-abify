# frozen_string_literal: true

require 'liquid'
require_relative 'hydra_manager'
require_relative 'liquid/processor'
require_relative 'liquid/context_builder'

# StepExecutor is responsible for executing a workflow step
# A step is basically an API request + response
class StepExecutor
  attr_reader :step, :row, :config, :execution

  def initialize(step, row, hydra_manager: HydraManager.instance, on_complete: nil, priority: false)
    raise ArgumentError, 'step is required' unless step
    raise ArgumentError, 'row is required' unless row

    @step = step
    @row = row
    @config = @step.step_config.with_indifferent_access
    @hydra_manager = hydra_manager
    @on_complete = on_complete
    @auth_config = @step.workflow&.resolved_auth_config || {}
    @priority = priority
    @execution = StepExecution.new(step: @step, row: @row)
  end

  def self.call(step, row)
    new(step, row).call
  end

  def call
    if should_skip?
      @execution.skip!
      Rails.logger.info "skipping row #{@row.source_index} step #{@step.order}"
      return
    end

    @execution.start!

    request_fields = render_request_fields
    Rails.logger.info "Queueing request for row #{@row.source_index} step #{@step.order}:"
    Rails.logger.info "  #{request_fields}"
    @hydra_manager.queue(
      **request_fields,
      front: @priority,
      auth_config: @auth_config,
      on_complete: lambda { |response|
        result = process_response(response)
        # TODO: store the request/response info somewhere and log it
        @on_complete&.call(result)
      }
    )
  end

  def should_skip?
    evaluate_boolean_condition('skip_condition')
  end

  def required?
    evaluate_boolean_condition('required')
  end

  private

  def process_response(response)
    if response.nil?
      @execution.fail!("No response received")
      return { success: false, error: "No response received" }
    end

    parsed_response = parse_json_response(response.body)
    if parsed_response.nil?
      @execution.fail!("Invalid JSON response")
      return { success: false, error: "Invalid JSON response" }
    end

    if response.code.between?(200, 299)
      success_data = extract_success_data(parsed_response)
      @execution.succeed!(success_data)
      { success: true, data: success_data }
    else
      error = parsed_response["errors"] || "Request failed with status #{response.code}"
      @execution.fail!(error)
      { success: false, error: error }
    end
  rescue StandardError => e
    @execution.fail!(e.message)
    { success: false, error: e.message }
  end

  def parse_json_response(body)
    return {} if body.nil? || body.empty?

    JSON.parse(body)
  rescue JSON::ParserError
    nil
  end

  def extract_success_data(parsed_response)
    success_templates = @config.dig('liquid_templates', 'success_data')
    return {} if success_templates.blank?
    return {} unless success_templates.is_a?(Hash)

    context_with_response = context.merge('response' => parsed_response)

    success_templates.each_with_object({}) do |(key, template), result|
      processor = Liquid::Processor.new(template, context_with_response)
      result[key] = processor.render
    rescue StandardError => e
      raise "Failed to extract required success data '#{key}': #{e.message}" if required?

      result[key] = nil
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
