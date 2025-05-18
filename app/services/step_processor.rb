# frozen_string_literal: true

require 'liquid'

##
# StepProcessor is responsible for processing a workflow step
class StepProcessor
  attr_reader :step, :context, :config

  def initialize(workflow_step, context)
    raise ArgumentError, 'workflow_step is required' unless workflow_step

    @step = workflow_step
    @context = context
    @config = @step.config.with_indifferent_access
  end

  def self.call(workflow_step, context)
    new(workflow_step, context).execute
  end
end
