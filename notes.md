structure idea

- app
  - models
    - data_sources
      - csv_data
      - json_data
      - mock_data
    - batch
    - batch_execution
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
    - batch_processor
    - hydra_manager
    - liquid
      - context_builder
      - filters
        - workflow_filters
      - processor
    - liquid_processor
    - row_processor
    - step_processor
    - workflow_executor
  - views
  - serializers
  - presenters
  - helpers
  - jobs
- lib
  - hydra_logger
- config


WorkflowExecution is AKA "An Import" or "A Run". It has a DataSource (a series of Rows), and a Worflow (a series of WorkflowSteps)

WorkflowExecutor creates a BatchProcessor and RowProcessor for each row in the data
- has a data_source
- has a workflow
- the workflow has steps
- has a method to start the execution

RowProcessor processes a single row through all workflow steps
- Uses StepProcessor for each individual step
- Handles step completion and row updates
- Manages step sequencing

StepProcessor
- processes the liquid syntax through LiquidProcessor
- handles hydra request queueing via HydraManager
- evaluates skip conditions
- extracts success data from responses

BatchProcessor
- Handles grouping of rows
- Manages batch execution ordering

LiquidProcessor and ContextBuilder
- Handles all liquid template processing
- Builds contexts for liquid template evaluation
- Custom workflow filters for template processing

Example Workflow YAML:
```yaml
name: "Create Subscriptions Workflow"
batch:
  group_by: >
    {% if row.group_primary %}
      {{row.reference}}
    {% else %}
      {{row.group_primary_reference}}
    {% endif %}
  sort_by: "{% if row.group_primary %}0{% else %}1{% endif %}"


steps:
  - name: "Look Up Customer"
    required: true
    skip_condition: "{{row.customer_id | present?}}"
    method: "get"
    url: "{{base}}/customers/lookup.json?reference={{row.customer_reference}}"
    success_key: "customer_id"
    success_value: "{{response.customer.id}}"


  - name: "Look Up Payment Profile"
    required: true
    skip_condition: "{{row.payment_profile_id | present?}}"
    method: "get"
    url: "{{base}}/payment_profiles.json"
    params:
      customer_id: "{{row.customer_id}}"
      sort: "created_at"
      order: "desc"
    success_key: "payment_profile_id"
    success_value: "{{response[0].id}}"


  - name: "Create Subscription"
    required: true
    method: "post"
    url: "{{base}}/subscriptions.json"
    body:
      subscription:
        customer_id: "{{row.customer_id}}"
        payment_profile_id: "{{row.payment_profile_id}}"
        next_billing_at: "{{row.next_billing_at}}"
        previous_billing_at: "{{row.previous_billing_at}}"
        product_handle: "{{row.product_handle}}"
        product_price_point_handle: "{{row.product_price_point_handle}}"
        components:
          $each_columns: "^component_(\\d+)_handle$"
          $if: "{{row['component_$index_handle']}}"
          $do:
            component_handle: "{{row[$value]}}"
            component_price_point_handle: "{{ row['component_$index_price_point_handle'] }}"
            component_quantity: "{{ row['component_$index_quantity'] }}"
    success_key: "subscription_id"
    success_value: "{{response.subscription.id}}"
    success_text: "{{base}}/subscriptions/{{response.subscription.id}}"
```
