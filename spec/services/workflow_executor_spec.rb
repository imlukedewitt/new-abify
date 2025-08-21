# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowExecutor do
  shared_context 'basic workflow executor setup' do
    let(:workflow) { build(:workflow) }
    let(:data_source) { build(:data_source) }
    let(:workflow_executor) { described_class.new(workflow, data_source) }
    let(:workflow_execution) { build(:workflow_execution, workflow: workflow, data_source: data_source) }

    before do
      allow(WorkflowExecution).to receive(:create!)
        .with(workflow: workflow, data_source: data_source)
        .and_return(workflow_execution)
      allow(workflow_execution).to receive(:start!)
      allow(workflow_execution).to receive(:complete!)
      allow(workflow_execution).to receive(:fail!)
    end
  end

  shared_context 'batching and liquid setup' do
    let(:row1) { instance_double(Row, data: { 'reference' => 'group_a', 'priority' => '1' }, source_index: 1) }
    let(:row2) { instance_double(Row, data: { 'reference' => 'group_a', 'priority' => '2' }, source_index: 2) }
    let(:row3) { instance_double(Row, data: { 'reference' => 'group_b', 'priority' => '1' }, source_index: 3) }
    let(:row_no_group_nil) { instance_double(Row, data: { 'id' => 4 }, source_index: 1) }
    let(:row_no_group_empty) { instance_double(Row, data: { 'reference' => '', 'id' => 5 }, source_index: 1) }
    let(:rows) { [row1, row2, row3, row_no_group_nil, row_no_group_empty] }

    let(:batch_a) { instance_double(Batch, id: 1) }
    let(:batch_b) { instance_double(Batch, id: 2) }
    let(:batch_ungrouped) { instance_double(Batch, id: 3) }

    let(:batch_processor_a) { instance_double(BatchProcessor, call: true) }
    let(:batch_processor_b) { instance_double(BatchProcessor, call: true) }
    let(:batch_processor_ungrouped) { instance_double(BatchProcessor, call: true) }

    let(:rows_relation) do
      double('ActiveRecord::Relation', update_all: true).tap do |relation|
        allow(relation).to receive(:group_by)
          .and_yield(row1)
          .and_yield(row2)
          .and_yield(row3)
          .and_yield(row_no_group_nil)
          .and_yield(row_no_group_empty)
          .and_return(
            {
              'group_a' => [
                row1, row2
              ],
              'group_b' => [row3],
              default: [
                row_no_group_nil, row_no_group_empty
              ]
            }
          )
      end
    end

    before do
      allow(workflow).to receive(:config).and_return(workflow_config) # TODO: Assumes workflow_config is defined in including context
      allow(data_source).to receive(:rows).and_return(rows_relation)
      allow(BatchProcessor).to receive(:new).with(batch: batch_a,
                                                  workflow: workflow).and_return(batch_processor_a)
      allow(BatchProcessor).to receive(:new).with(batch: batch_b,
                                                  workflow: workflow).and_return(batch_processor_b)
      allow(BatchProcessor).to receive(:new).with(batch: batch_ungrouped,
                                                  workflow: workflow).and_return(batch_processor_ungrouped)
    end

    def expect_ordered_call(receiver, method, args, return_value)
      expectation = expect(receiver).to receive(method).ordered
      if args.empty?
        expectation.with(no_args)
      else
        expectation.with(*args)
      end
      expectation.and_return(return_value)
    end

    def expect_liquid_processing(row_double, expected_render_result, template_content)
      lp_double = instance_double(Liquid::Processor)
      context_data = { 'row' => row_double.data }

      expect_ordered_call(Liquid::ContextBuilder, :new, [hash_including(row: row_double)],
                          double(build: context_data))
      expect_ordered_call(Liquid::Processor, :new, [template_content, context_data], lp_double)
      expect_ordered_call(lp_double, :render, [], expected_render_result)
    end

    def expect_batch_processing(batch_double, rows_in_batch, processing_mode, processor_double)
      expect_ordered_call(Batch, :create!, [hash_including(processing_mode: processing_mode)], batch_double)
      rows_in_batch.each { |r| expect_ordered_call(r, :update!, [{ batch_id: batch_double.id }], nil) }
      expect_ordered_call(processor_double, :call, [], nil)
    end
  end

  describe '#initialize' do
    let(:workflow) { create(:workflow) }
    let(:data_source) { create(:data_source) }

    let(:workflow_executor) { described_class.new(workflow, data_source) }

    it 'assigns all necessary attributes' do
      expect(workflow_executor.workflow).to eq(workflow)
      expect(workflow_executor.data_source).to eq(data_source)
      expect(workflow_executor.data_source).to be_a(DataSource)
      expect(workflow_executor.hydra_manager).to be_a(HydraManager)
    end
  end

  describe '#call' do
    include_context 'basic workflow executor setup'
    let(:rows_relation) { double('ActiveRecord::Relation', update_all: true) }

    before do
      allow(data_source).to receive(:rows).and_return(rows_relation)
      allow(workflow_execution).to receive(:start!)
      allow(workflow_execution).to receive(:complete!)
      allow(workflow_execution).to receive(:fail!)
    end

    it 'creates and starts a workflow execution and updates rows' do
      expect(rows_relation).to receive(:update_all).with(workflow_execution_id: workflow_execution.id)
      expect(workflow_execution).to receive(:start!)

      result = workflow_executor.call
      expect(result).to eq(workflow_execution)
      expect(workflow_executor.execution).to eq(workflow_execution)
    end

    context 'when workflow has no batching configuration' do
      let(:batch_processor_double) { instance_double(BatchProcessor, call: true) }
      let(:batch_double) { instance_double(Batch, id: 123) }

      before do
        # Workflow config without liquid_templates or with empty liquid_templates
        allow(workflow).to receive(:config).and_return({ 'liquid_templates' => {} })
        expect(Batch).to receive(:create!).with(
          hash_including(
            processing_mode: "parallel",
            workflow_execution: workflow_execution
          )
        ).and_return(batch_double)
        allow(BatchProcessor).to receive(:new).with(batch: batch_double,
                                                    workflow: workflow).and_return(batch_processor_double)
      end

      it 'processes all rows in a single batch' do
        expect(rows_relation).to receive(:update_all).with(workflow_execution_id: workflow_execution.id).ordered
        expect(rows_relation).to receive(:update_all).with(batch_id: batch_double.id).ordered

        workflow_executor.call

        expect(batch_processor_double).to have_received(:call)
      end
    end

    context 'when workflow has batching configuration' do
      include_context 'batching and liquid setup'

      let(:workflow_config) do
        { 'liquid_templates' => { 'group_by' => '{{row.reference}}' } }
      end

      it 'correctly evaluates Liquid group_by templates for all rows' do
        group_by_template = workflow_config['liquid_templates']['group_by']

        expect_liquid_processing(row1, 'group_a', group_by_template)
        expect_liquid_processing(row2, 'group_a', group_by_template)
        expect_liquid_processing(row3, 'group_b', group_by_template)
        expect_liquid_processing(row_no_group_nil, nil, group_by_template)
        expect_liquid_processing(row_no_group_empty, '', group_by_template)

        allow(Batch).to receive(:create!).and_return(instance_double(Batch, id: 999))
        rows.each { |r| allow(r).to receive(:update!) }
        allow(BatchProcessor).to receive(:new).and_return(instance_double(BatchProcessor, call: true))

        workflow_executor.call
      end

      it 'creates and processes batches according to grouping results' do
        expect_batch_processing(batch_a, [row1, row2], "sequential", batch_processor_a)
        expect_batch_processing(batch_b, [row3], "sequential", batch_processor_b)
        expect_batch_processing(batch_ungrouped, [row_no_group_nil, row_no_group_empty], "parallel",
                                batch_processor_ungrouped)

        workflow_executor.call
      end

      context 'when workflow has sorting configuration' do
        let(:workflow_config) do # Specific config for sorting tests
          {
            'liquid_templates' => {
              'group_by' => '{{row.reference}}', # Used by liquid mocks
              'sort_by' => '{{row.priority}}' # Used by liquid mocks
            }
          }
        end

        let(:high_priority_row) { instance_double(Row, data: { 'reference' => 'group_a', 'priority' => '1' }) }
        let(:low_priority_row) { instance_double(Row, data: { 'reference' => 'group_a', 'priority' => '2' }) }
        let(:other_group_row) { instance_double(Row, data: { 'reference' => 'group_b', 'priority' => '3' }) }

        before do
          allow(workflow).to receive(:config).and_return(workflow_config)
          allow(data_source).to receive(:rows)
            .and_return(
              double('ActiveRecord::Relation', update_all: true).tap do |relation|
                allow(relation).to receive(:group_by)
                  .and_yield(low_priority_row).and_yield(high_priority_row).and_yield(other_group_row)
                  .and_return({ 'group_a' => [low_priority_row, high_priority_row], 'group_b' => [other_group_row] })
                allow(relation).to receive(:sort_by).and_yield(low_priority_row).and_yield(high_priority_row)
                  .and_return([high_priority_row, low_priority_row])
              end
            )
          setup_liquid_mocks
          setup_batch_mocks
        end

        def setup_liquid_mocks
          stub_liquid_context_builder
          stub_liquid_processor
        end

        def stub_liquid_context_builder
          allow(Liquid::ContextBuilder).to receive(:new).and_wrap_original do |_original, args|
            row = args[:row]
            double(build: { 'row' => row.data })
          end
        end

        def stub_liquid_processor
          allow(Liquid::Processor).to receive(:new).and_wrap_original do |_original, template, context|
            processor_double = instance_double(Liquid::Processor)
            allow(processor_double).to receive(:render).and_return(evaluate_mocked_template(template, context))
            processor_double
          end
        end

        def evaluate_mocked_template(template, context)
          if template == workflow_config['liquid_templates']['group_by']
            context['row']['reference']
          elsif template == workflow_config['liquid_templates']['sort_by']
            context['row']['priority']
          end
        end

        def setup_batch_mocks
          setup_row_update_mocks
          setup_batch_creation_mocks
          setup_batch_processor_mocks
        end

        def setup_row_update_mocks
          [high_priority_row, low_priority_row, other_group_row].each do |row|
            allow(row).to receive(:update!).and_return(true)
          end
        end

        def setup_batch_creation_mocks
          @sort_batch_a = instance_double(Batch, id: 101) # Different IDs
          @sort_batch_b = instance_double(Batch, id: 102)
          allow(Batch).to receive(:create!).with(hash_including(processing_mode: "sequential"))
                                           .and_return(@sort_batch_a, @sort_batch_b)
        end

        def setup_batch_processor_mocks
          sort_batch_processor_a = instance_double(BatchProcessor, call: true)
          sort_batch_processor_b = instance_double(BatchProcessor, call: true)
          allow(BatchProcessor).to receive(:new).with(batch: @sort_batch_a, workflow: workflow)
                                                .and_return(sort_batch_processor_a)
          allow(BatchProcessor).to receive(:new).with(batch: @sort_batch_b, workflow: workflow)
                                                .and_return(sort_batch_processor_b)
        end

        it 'sorts rows within each group by priority (lowest first)' do
          workflow_executor.call

          # Verify that high priority (1) is processed before low priority (2) within group_a
          expect(high_priority_row).to have_received(:update!).ordered
          expect(low_priority_row).to have_received(:update!).ordered
          expect(other_group_row).to have_received(:update!).ordered
        end

        context 'when sort_by template is not provided' do
          let(:workflow_config) do
            {
              'liquid_templates' => {
                'group_by' => '{{row.reference}}'
              }
            }
          end

          it 'preserves original order within groups' do
            workflow_executor.call

            # Should maintain the original order: low_priority_row, high_priority_row, other_group_row
            expect(low_priority_row).to have_received(:update!).ordered
            expect(high_priority_row).to have_received(:update!).ordered
            expect(other_group_row).to have_received(:update!).ordered
          end
        end

        context 'when rows have identical sort values' do
          let(:identical_priority_row1) { instance_double(Row, data: { 'reference' => 'group_a', 'priority' => '1' }) }
          let(:identical_priority_row2) { instance_double(Row, data: { 'reference' => 'group_a', 'priority' => '1' }) }

          before do
            allow(data_source).to receive(:rows).and_return(double('ActiveRecord::Relation',
                                                                   update_all: true).tap do |relation|
              allow(relation).to receive(:group_by).and_yield(identical_priority_row2).and_yield(identical_priority_row1).and_return({
                                                                                                                                       'group_a' => [
                                                                                                                                         identical_priority_row2, identical_priority_row1
                                                                                                                                       ]
                                                                                                                                     })
              allow(relation).to receive(:sort_by).and_yield(identical_priority_row2).and_yield(identical_priority_row1).and_return([
                                                                                                                                      identical_priority_row2, identical_priority_row1
                                                                                                                                    ])
            end)
            [identical_priority_row1, identical_priority_row2].each do |row|
              allow(row).to receive(:update!).and_return(true)
            end
          end

          it 'maintains stable sort order' do
            workflow_executor.call

            expect(identical_priority_row2).to have_received(:update!).ordered
            expect(identical_priority_row1).to have_received(:update!).ordered
          end
        end
      end
    end
  end
end
