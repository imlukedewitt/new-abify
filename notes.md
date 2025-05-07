structure idea

- app
  - models
    - data_sources
      - csv_data
      - json_data
      - mock_data
    - config
    - data_source
    - import
    - row
    - step
    - user
    - workflow
    - workflow_execution
  - controllers
    - api
    - v1
      - workflows
        - steps
        - workflow_executions
      - users
  - services
    - hydra_manager
    - row_processor
    - workflow_executor
    - workflow_step_executor
  - views
  - serializers
  - presenters
  - helpers
  - jobs
- lib
  - hydra_logger
- config


WorkflowExecution is AKA "An Import" or "A Run". It has a DataSource (a series of Rows), and a Worflow (a series of WorkflowSteps)

WorkflowExecutor creates a RowProcessor for each row in the data

RowProcessor creates a WorkflowStepExecutor for each WorkflowStep

WorkflowStepExecutor
- processes the liquid syntax
- handles hydra queueing

