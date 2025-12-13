# frozen_string_literal: true

require 'liquid'
require_relative 'hydra_manager'
require_relative 'liquid/step_templates'
require_relative 'liquid/context_builder'

# StepExecutor is responsible for executing a workflow step
# A step is basically an API request + response
class StepExecutor
  attr_reader :step, :row, :config, :execution

  def initialize(step, row, row_execution: nil, hydra_manager: HydraManager.instance, on_complete: nil, priority: false)
    raise ArgumentError, 'step is required' unless step
    raise ArgumentError, 'row is required' unless row

    @step = step
    @row = row
    @row_execution = row_execution
    @config = @step.step_config.with_indifferent_access
    @hydra_manager = hydra_manager
    @on_complete = on_complete
    @auth_config = @step.workflow&.resolved_auth_config || {}
    @priority = priority
    @execution = StepExecution.new(step: @step, row: @row, row_execution: @row_execution)
    @templates = Liquid::StepTemplates.new(@config['liquid_templates'])
  end

  def self.call(step, row)
    new(step, row).call
  end

  def call
    return skip! if should_skip?

    @execution.start!
    queue_request
  end

  def should_skip?
    @templates.skip?(context)
  end

  def required?
    @templates.required?(context)
  end

  private

  def skip!
    @execution.skip!
    Rails.logger.info "skipping row #{@row.source_index} step #{@step.order}"
  end

  def queue_request
    request_fields = @templates.render_request(context)
    Rails.logger.info "Queueing request for row #{@row.source_index} step #{@step.order}:"
    Rails.logger.info "  #{request_fields}"

    @hydra_manager.queue(
      **request_fields,
      front: @priority,
      auth_config: @auth_config,
      on_complete: ->(response) { @on_complete&.call(process_response(response)) }
    )
  end

  def process_response(response)
    return fail_response("No response received") if response.nil?

    parsed = parse_json_response(response.body)
    return fail_response("Invalid JSON response") if parsed.nil?

    response.code.between?(200, 299) ? handle_success(parsed) : handle_error(parsed, response.code)
  rescue StandardError => e
    fail_response(e.message)
  end

  def handle_success(parsed)
    context_with_response = context.merge('response' => parsed)
    success_data = @templates.extract_success_data(context_with_response, required: required?)
    @execution.succeed!(success_data)
    { success: true, data: success_data }
  end

  def handle_error(parsed, code)
    error = parsed["errors"] || "Request failed with status #{code}"
    fail_response(error)
  end

  def fail_response(error)
    @execution.fail!(error)
    { success: false, error: error }
  end

  def parse_json_response(body)
    return {} if body.nil? || body.empty?

    JSON.parse(body)
  rescue JSON::ParserError
    nil
  end

  def context
    @context ||= Liquid::ContextBuilder.new(
      row: @row,
      workflow: @step.workflow,
      row_execution: @row_execution
    ).build
  end
end
