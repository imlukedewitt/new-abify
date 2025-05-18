# frozen_string_literal: true

##
# WorkflowExecutor creates a RowProcessor for every Row in the Data Source
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
