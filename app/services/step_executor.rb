# frozen_string_literal: true

require 'liquid'
require_relative 'hydra_manager'
require_relative 'liquid/step_templates'
require_relative 'liquid/context_builder'

# StepExecutor is responsible for executing a workflow step
# A step is basically an API request + response
class StepExecutor
  attr_reader :step, :row, :config, :execution

  def initialize(step, row, step_templates:, **options)
    raise ArgumentError, 'step is required' unless step
    raise ArgumentError, 'row is required' unless row

    @step = step
    @row = row
    @config = @step.step_config.with_indifferent_access
    @row_execution = options[:row_execution]
    @hydra_manager = options.fetch(:hydra_manager, HydraManager.instance)
    @on_complete = options[:on_complete]
    @resolved_connections = options.fetch(:resolved_connections, {})
    @priority = options.fetch(:priority, false)

    @connection = resolve_connection
    @auth_config = @connection&.credentials || {}
    @execution = StepExecution.new(step: @step, row: @row, row_execution: @row_execution)
    @templates = step_templates.fetch(@step.id)
  end

  def call
    return skip! if should_skip?

    @execution.start!

    # We only fail early if using the new connection slot system
    if @connection.nil? && @step.workflow.connection_slots.present?
      error = 'No connection available'
      Rails.logger.error "Row #{@row.source_index} step #{@step.order} failed: #{error}"
      return @on_complete&.call(fail_response(error))
    end

    queue_request
  end

  def should_skip?
    @templates.skip?(context)
  end

  def required?
    @templates.required?(context)
  end

  private

  def resolve_connection
    explicit_handle = @config.dig(:liquid_templates, :connection_slot).presence
    default_handle = @step.workflow.connection_slots&.find { |s| s['default'] }&.dig('handle')

    @resolved_connections[explicit_handle] || @resolved_connections[default_handle]
  end

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
    return fail_response('No response received') if response.nil?

    parsed = parse_json_response(response.body)
    return fail_response('Invalid JSON response') if parsed.nil?

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
    error = parsed['errors'] || "Request failed with status #{code}"
    fail_response(error)
  end

  def fail_response(error)
    slot_handle = @config.dig(:liquid_templates, :connection_slot)
    slot_info = slot_handle ? "slot '#{slot_handle}'" : 'default slot'
    connection_name = @connection&.name

    context = "Connection #{slot_info}"
    context += " ('#{connection_name}')" if connection_name

    full_error = "#{context}: #{error}"

    @execution.fail!(full_error)
    { success: false, error: full_error }
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
      row_execution: @row_execution,
      connection: @connection
    ).build
  end
end
