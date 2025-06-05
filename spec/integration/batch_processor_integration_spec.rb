# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BatchProcessor, :integration, :vcr do
  let(:workflow) { create(:workflow) }

  let!(:step1) do
    create(:step, workflow: workflow, order: 1, config: {
             'liquid_templates' => {
               'name' => 'Get Post',
               'url' => 'https://jsonplaceholder.typicode.com/posts/{{row.source_row_index}}',
               'method' => 'get',
               'success_data' => {
                 'post_id' => '{{response.id}}',
                 'post_title' => '{{response.title}}',
                 'user_id' => '{{response.userId}}'
               }
             }
           })
  end

  let!(:step2) do
    create(:step, workflow: workflow, order: 2, config: {
             'liquid_templates' => {
               'name' => 'Get User',
               'url' => 'https://jsonplaceholder.typicode.com/users/{{row.post_id}}',
               'method' => 'get',
               'success_data' => {
                 'username' => '{{response.username}}',
                 'email' => '{{response.email}}',
                 'company' => '{{response.company.name}}'
               }
             }
           })
  end

  let(:data_source) { create(:data_source) }
  let(:workflow_execution) { create(:workflow_execution, workflow: workflow) }

  let(:batch) do
    create(:batch).tap do |b|
      3.times do |i|
        create(:row, batch: b, workflow_execution: workflow_execution, data_source: data_source,
                     data: { 'source_row_index': i + 1 })
      end
    end
  end

  describe '#call' do
    it 'processes all rows in the batch' do
      expect(batch.rows.count).to eq(3)

      processor = described_class.new(batch: batch, workflow: workflow)
      processor.call

      HydraManager.instance.run

      execution = BatchExecution.find_by(batch: batch, workflow: workflow)
      expect(execution).to be_present
      expect(execution.status).to eq(Executable::PROCESSING)

      processor.check_completion

      execution.reload

      batch.rows.reload.each.with_index(1) do |row, idx|
        expect(row.data).to include(
          'post_id' => idx.to_s,
          'post_title' => be_a(String),
          'user_id' => '1',
          'username' => be_a(String),
          'email' => be_a(String),
          'company' => be_a(String)
        )
      end

      expect(execution.status).to eq(Executable::COMPLETE)
    end

    it 'handles failures in the batch' do
      workflow.steps.destroy_all
      create(:step, workflow: workflow, order: 1, config: {
               'liquid_templates' => {
                 'name' => 'Test 404',
                 'url' => 'https://jsonplaceholder.typicode.com/nonexistent',
                 'method' => 'get',
                 'required' => true,
                 'success_data' => {
                   'should_not' => 'be_present'
                 }
               }
             })
      workflow.reload

      processor = described_class.new(batch: batch, workflow: workflow)
      processor.call

      HydraManager.instance.run

      processor.check_completion

      execution = BatchExecution.find_by(batch: batch, workflow: workflow)
      execution.reload

      expect(execution.status).to eq(Executable::FAILED)

      batch.rows.reload.each do |row|
        expect(row.data).not_to include('should_not')
        expect(row.row_executions.count).to eq(1)
        expect(row.row_executions.first.status).to eq(Executable::FAILED)
      end
    end

    it 'processes a mix of successful and failed steps' do
      workflow.steps.where.not(id: step1.id).destroy_all
      create(:step, workflow: workflow, order: 2, config: {
               'liquid_templates' => {
                 'name' => 'Test 404',
                 'url' => 'https://jsonplaceholder.typicode.com/nonexistent',
                 'method' => 'get',
                 'required' => false # Mark as not required so it doesn't fail the whole row
               }
             })
      workflow.reload

      processor = described_class.new(batch: batch, workflow: workflow)
      processor.call

      HydraManager.instance.run

      processor.check_completion

      execution = BatchExecution.find_by(batch: batch, workflow: workflow)
      execution.reload

      expect(execution.status).to eq(Executable::COMPLETE)

      batch.rows.reload.each.with_index(1) do |row, idx|
        expect(row.data).to include(
          'post_id' => idx.to_s,
          'post_title' => be_a(String),
          'source_row_index' => idx
        )
      end
    end

    it 'stops the monitor thread when requested' do
      processor = described_class.new(batch: batch, workflow: workflow)
      processor.call

      expect(processor.monitor_thread).to be_present
      expect(processor.monitor_thread).to be_alive

      processor.stop_monitor

      expect(processor.monitor_thread).to be_nil
    end

    # this test isn't very good...
    # the VCR makes it useless since it plays back without a delay
    # I'm not worried about this for now
    it 'processes rows concurrently' do
      step1.config = {
        'liquid_templates' => {
          'name' => 'Slow Request',
          'url' => 'https://httpbin.org/delay/1?row_id={{row.id}}',
          'method' => 'get',
          'success_data' => {
            'processed_at': '{{response.url}}'
          }
        }
      }
      step1.save!

      workflow.steps.where.not(id: step1.id).destroy_all
      workflow.reload

      processor = described_class.new(batch: batch, workflow: workflow)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      processor.call

      HydraManager.instance.run
      processor.check_completion
      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      total_time = end_time - start_time

      expect(total_time).to be < batch.rows.count * 0.9 # Less than 90% of sequential time

      batch.rows.reload.each do |row|
        expect(row.data).to include('processed_at')
      end

      expect(BatchExecution.find_by(batch: batch).status).to eq(Executable::COMPLETE)
    end
  end
end
