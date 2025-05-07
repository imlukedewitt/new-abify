# frozen_string_literal: true

##
# WorkflowExecutor is responsible for executing a workflow, which is a series of steps
# Creates a WorkflowStepExecutor for each row in the data source
# and executes each step in the workflow
class WorkflowExecutor
  attr_reader :workflow, :data_source, :hydra_manager, :response

  def initialize(workflow, data_source, hydra_manager = HydraManager.instance)
    raise ArgumentError, 'workflow is required' unless workflow
    raise ArgumentError, 'data_source is required' unless data_source

    @hydra_manager = hydra_manager
    @workflow = workflow
    @data_source = data_source
  end
end
