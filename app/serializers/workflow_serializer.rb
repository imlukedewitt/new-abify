# frozen_string_literal: true

# Serializes a workflow object
#
# @param [Workflow] workflow The workflow to serialize
# @param [Hash] options The options for the serializer
# @return [Hash] The serialized workflow
# @option options [Boolean] :include_steps whether to include the steps in the serialized workflow
# @option options [Boolean] :include_config whether to include the config in the serialized workflow
class WorkflowSerializer
  def initialize(workflow, options = {})
    @workflow = workflow
    @options = options
  end

  def as_json(_options = {})
    {
      id: @workflow.id,
      name: @workflow.name,
      created_at: @workflow.created_at.as_json,
      updated_at: @workflow.updated_at.as_json
    }.tap do |json|
      json[:steps] = serialize_steps if include_steps?
      json[:config] = @workflow.config if include_config?
    end
  end

  private

  def include_steps?
    @options[:include_steps].present?
  end

  def include_config?
    @options[:include_config].present?
  end

  def serialize_steps
    @workflow.steps.map { |step| StepSerializer.new(step).as_json }
  end
end
