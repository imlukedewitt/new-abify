# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecutor, :integration, :vcr do
  describe '#call' do
    context 'when processing a simple workflow without grouping' do
      let!(:simple_workflow) { create(:workflow, name: 'Simple Post Fetcher Workflow') }
      let!(:simple_step) do
        create(:step, workflow: simple_workflow, order: 1, config: {
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

      let!(:simple_data_source) do
        create(:data_source, name: 'Simple DS for Post Fetcher').tap do |ds|
          create(:row, data_source: ds, data: { 'post_id_input' => 1 })
          create(:row, data_source: ds, data: { 'post_id_input' => 2 })
        end
      end

      let(:simple_workflow_executor) { described_class.new(simple_workflow, simple_data_source) }

      it 'successfully processes all rows in the data source through the workflow' do
        expect(simple_data_source.rows.count).to eq(2)
        initial_workflow_execution_count = WorkflowExecution.count
        initial_batch_count = Batch.count

        workflow_execution_result = simple_workflow_executor.call

        expect(WorkflowExecution.count).to eq(initial_workflow_execution_count + 1)
        expect(workflow_execution_result).to be_a(WorkflowExecution)
        expect(workflow_execution_result.status).to eq(Executable::COMPLETE)
        expect(workflow_execution_result.workflow).to eq(simple_workflow)
        expect(workflow_execution_result.data_source).to eq(simple_data_source)

        expect(Batch.count).to eq(initial_batch_count + 1)
        # Fetch the batch associated with this execution
        batch = workflow_execution_result.batches.first
        expect(batch).not_to be_nil
        expect(batch.processing_mode).to eq('parallel') # Default if no grouping
        expect(batch.rows.count).to eq(2)

        processed_rows = batch.rows.order(Arel.sql('data->>\'post_id_input\' ASC')) # Ensure consistent order

        row_exec_0 = processed_rows[0].row_executions.first
        expect(row_exec_0.merged_success_data).to include(
          'fetched_title' => 'sunt aut facere repellat provident occaecati excepturi optio reprehenderit',
          'original_id' => '1'
        )

        row_exec_1 = processed_rows[1].row_executions.first
        expect(row_exec_1.merged_success_data).to include(
          'fetched_title' => 'qui est esse',
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

    context 'when processing a workflow with grouping configuration' do
      let!(:grouping_workflow) do
        create(:workflow, name: 'Grouping Todo Fetcher Workflow', config: {
                 'liquid_templates' => { 'group_by' => '{{row.category}}' }
               })
      end

      let!(:grouping_step) do
        create(:step, workflow: grouping_workflow, order: 1, config: {
                 'liquid_templates' => {
                   'name' => 'Get Todo Title by Category',
                   'url' => 'https://jsonplaceholder.typicode.com/todos/{{row.id_input}}',
                   'method' => 'get',
                   'success_data' => {
                     'fetched_todo_title' => '{{response.title}}',
                     'original_category' => '{{row.category}}', # Capture category at processing time
                     'original_id_input' => '{{row.id_input}}'  # Capture id_input at processing time
                   }
                 }
               })
      end

      let!(:grouping_data_source) do
        create(:data_source, name: 'Grouping DS for Todo Fetcher').tap do |ds|
          # Group A
          create(:row, data_source: ds, data: { 'category' => 'A', 'id_input' => 1 }) # Fetches todo 1
          create(:row, data_source: ds, data: { 'category' => 'A', 'id_input' => 2 }) # Fetches todo 2
          # Group B
          create(:row, data_source: ds, data: { 'category' => 'B', 'id_input' => 3 }) # Fetches todo 3
          # Ungrouped (nil category) - will be grouped with empty string category
          create(:row, data_source: ds, data: { 'id_input' => 4 }) # Fetches todo 4
          # Ungrouped (empty string category)
          create(:row, data_source: ds, data: { 'category' => '', 'id_input' => 5 }) # Fetches todo 5
        end
      end

      let(:grouping_workflow_executor) { described_class.new(grouping_workflow, grouping_data_source) }

      it 'correctly processes rows, creating appropriate sequential and parallel batches' do
        initial_workflow_execution_count = WorkflowExecution.count
        initial_batch_count = Batch.count

        workflow_execution_result = grouping_workflow_executor.call

        expect(WorkflowExecution.count).to eq(initial_workflow_execution_count + 1)
        expect(workflow_execution_result).to be_a(WorkflowExecution)
        expect(workflow_execution_result.status).to eq(Executable::COMPLETE)
        expect(workflow_execution_result.workflow).to eq(grouping_workflow)
        expect(workflow_execution_result.data_source).to eq(grouping_data_source)

        # Expect 3 batches: 'A', 'B', and one for ungrouped (nil + empty string)
        expect(Batch.count).to eq(initial_batch_count + 3)
        execution_batches = workflow_execution_result.batches.includes(:rows)
        expect(execution_batches.count).to eq(3)

        # --- Verify Batch for Category A (Sequential) ---
        rows_cat_a_initial = grouping_data_source.rows.select { |r| r.data['category'] == 'A' }
        expect(rows_cat_a_initial.count).to eq(2)
        # All rows from the same group should be in the same batch
        batch_ids_cat_a = rows_cat_a_initial.map { |r| r.reload.batch_id }.uniq
        expect(batch_ids_cat_a.count).to eq(1)
        batch_a = Batch.find(batch_ids_cat_a.first)

        expect(batch_a.processing_mode).to eq('sequential')
        expect(batch_a.rows.count).to eq(2)
        batch_a.rows.sort_by { |row| row.data['id_input'].to_i }.each do |row|
          row_exec = row.row_executions.first
          success_data = row_exec.merged_success_data
          expect(success_data['original_category']).to eq('A')
          expect(success_data).to have_key('fetched_todo_title')
          if success_data['original_id_input'].to_i == 1
            expect(success_data['fetched_todo_title']).to eq('delectus aut autem')
          elsif success_data['original_id_input'].to_i == 2
            expect(success_data['fetched_todo_title']).to eq('quis ut nam facilis et officia qui')
          end
        end

        # --- Verify Batch for Category B (Sequential) ---
        rows_cat_b_initial = grouping_data_source.rows.select { |r| r.data['category'] == 'B' }
        expect(rows_cat_b_initial.count).to eq(1)
        batch_ids_cat_b = rows_cat_b_initial.map { |r| r.reload.batch_id }.uniq
        expect(batch_ids_cat_b.count).to eq(1)
        batch_b = Batch.find(batch_ids_cat_b.first)

        expect(batch_b.processing_mode).to eq('sequential')
        expect(batch_b.rows.count).to eq(1)
        row_b = batch_b.rows.first
        success_data_b = row_b.row_executions.first.merged_success_data
        expect(success_data_b['original_category']).to eq('B')
        expect(success_data_b['original_id_input'].to_i).to eq(3)
        expect(success_data_b['fetched_todo_title']).to eq('fugiat veniam minus')

        # --- Verify Batch for Ungrouped (Parallel) ---
        # Rows with nil or empty string category are grouped together by WorkflowExecutor
        rows_ungrouped_initial = grouping_data_source.rows.select { |r| r.data['category'].blank? }
        expect(rows_ungrouped_initial.count).to eq(2)
        batch_ids_ungrouped = rows_ungrouped_initial.map { |r| r.reload.batch_id }.uniq
        expect(batch_ids_ungrouped.count).to eq(1)
        batch_ungrouped = Batch.find(batch_ids_ungrouped.first)

        expect(batch_ungrouped.processing_mode).to eq('parallel')
        expect(batch_ungrouped.rows.count).to eq(2)
        batch_ungrouped.rows.sort_by { |row| row.data['id_input'].to_i }.each do |row|
          row_exec = row.row_executions.first
          success_data = row_exec.merged_success_data
          # original_category might be nil or empty string, reflecting the input
          expect(success_data['original_category'].blank? || success_data['original_category'] == row.data['category'])
            .to be true
          expect(success_data).to have_key('fetched_todo_title')
          if success_data['original_id_input'].to_i == 4
            expect(success_data['fetched_todo_title']).to eq('et porro tempora')
          elsif success_data['original_id_input'].to_i == 5
            expect(success_data['fetched_todo_title'])
              .to eq('laboriosam mollitia et enim quasi adipisci quia provident illum')
          end
        end

        # Verify all rows from the data source were processed and have execution records
        grouping_data_source.rows.each do |row|
          row.reload # Ensure we have the latest data from the DB
          expect(row.batch_id).not_to be_nil # Should be assigned to a batch
          expect(row.row_executions.count).to eq(1)
          row_execution = row.row_executions.first
          expect(row_execution.status).to eq(Executable::COMPLETE)
          expect(row_execution.step_executions.count).to eq(1)
          expect(row_execution.step_executions.first.status).to eq(Executable::SUCCESS)
        end
      end
    end
  end
end
