# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecutor, :integration, :vcr do
  let!(:workflow) { create(:workflow, name: 'Simple Post Fetcher Workflow') }
  let!(:step1) do
    create(:step, workflow: workflow, order: 1, config: {
             'liquid_templates' => {
               'name' => 'Get Post Title',
               'url' => 'https://jsonplaceholder.typicode.com/posts/{{row.post_id_input}}',
               'method' => 'get',
               'success_data' => {
                 'fetched_title' => '{{response.title}}',
                 'original_id' => '{{row.post_id_input}}' # Keep original for verification
               }
             }
           })
  end

  let!(:data_source) do
    create(:data_source).tap do |ds|
      create(:row, data_source: ds, data: { 'post_id_input' => 1 })
      create(:row, data_source: ds, data: { 'post_id_input' => 2 })
    end
  end

  let(:workflow_executor) { described_class.new(workflow, data_source) }

  describe '#call' do
    it 'successfully processes all rows in the data source through the workflow' do
      expect(data_source.rows.count).to eq(2)
      initial_batch_count = Batch.count

      workflow_execution_result = workflow_executor.call

      expect(workflow_execution_result).to be_a(WorkflowExecution)
      expect(workflow_execution_result.status).to eq(Executable::COMPLETE)
      expect(workflow_execution_result.workflow).to eq(workflow)
      expect(workflow_execution_result.data_source).to eq(data_source)

      expect(Batch.count).to eq(initial_batch_count + 1)
      batch = Batch.last
      expect(batch.processing_mode).to eq('parallel')
      expect(batch.rows.count).to eq(2)

      processed_rows = batch.rows.sort_by { |r| r.data['post_id_input'] }

      expect(processed_rows[0].data).to include(
        'post_id_input' => 1, # Original data should persist
        'fetched_title' => 'sunt aut facere repellat provident occaecati excepturi optio reprehenderit', # From post 1
        'original_id' => '1'
      )
      expect(processed_rows[1].data).to include(
        'post_id_input' => 2, # Original data
        'fetched_title' => 'qui est esse', # From post 2
        'original_id' => '2'
      )

      processed_rows.each do |row|
        expect(row.row_executions.count).to eq(1)
        row_execution = row.row_executions.first
        expect(row_execution.status).to eq(Executable::COMPLETE)
        expect(row_execution.step_executions.count).to eq(1)
        expect(row_execution.step_executions.first.status).to eq(Executable::SUCCESS)
      end
    end
  end
end
