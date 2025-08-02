# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workflow, type: :model do
  describe 'associations' do
    it 'has many steps' do
      association = described_class.reflect_on_association(:steps)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :destroy
    end

    it 'has many workflow_executions' do
      association = described_class.reflect_on_association(:workflow_executions)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :restrict_with_error
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      workflow = build(:workflow, name: nil)
      expect(workflow).not_to be_valid
      expect(workflow.errors[:name]).to include("can't be blank")
    end
  end

  describe '#config validation' do
    context 'when config is nil' do
      it 'is valid' do
        workflow = build(:workflow, config: nil)
        expect(workflow).to be_valid
      end
    end

    context 'when config is not a hash' do
      it 'is invalid' do
        workflow = build(:workflow, config: 'not a hash')
        expect(workflow).not_to be_valid
        expect(workflow.errors[:config]).to include('must be a hash')
      end
    end

    context 'when workflow config has unknown sections' do
      it 'is invalid' do
        workflow = build(:workflow, config: {
                           'workflow' => { 'unknown_section' => {} }
                         })
        expect(workflow).not_to be_valid
        expect(workflow.errors[:config]).to include('unexpected section in workflow config: unknown_section')
      end
    end

    context 'liquid_templates section' do
      context 'when liquid_templates is not a hash' do
        it 'is invalid' do
          workflow = build(:workflow, config: {
                             'workflow' => { 'liquid_templates' => 'not a hash' }
                           })
          expect(workflow).not_to be_valid
          expect(workflow.errors[:config]).to include('workflow.liquid_templates must be a hash')
        end
      end

      context 'when liquid_templates has unknown keys' do
        it 'is invalid' do
          workflow = build(:workflow, config: {
                             'workflow' => {
                               'liquid_templates' => { 'unknown_key' => 'value' }
                             }
                           })
          expect(workflow).not_to be_valid
          expect(workflow.errors[:config]).to include('unexpected key in workflow.liquid_templates: unknown_key')
        end
      end

      context 'when liquid_templates has valid keys' do
        it 'is valid' do
          workflow = build(:workflow, config: {
                             'workflow' => {
                               'liquid_templates' => {
                                 'group_by' => '{{row.category}}',
                                 'sort_by' => '{{row.priority}}'
                               }
                             }
                           })
          expect(workflow).to be_valid
        end
      end

      context 'when liquid_templates has invalid Liquid syntax' do
        it 'is invalid' do
          workflow = build(:workflow, config: {
                             'workflow' => {
                               'liquid_templates' => {
                                 'group_by' => '{{row.category' # Missing closing braces
                               }
                             }
                           })
          expect(workflow).not_to be_valid
          expect(workflow.errors[:config].first).to include('invalid Liquid syntax in workflow.liquid_templates.group_by')
        end
      end

      context 'when liquid_templates has nil or empty values' do
        it 'is valid' do
          workflow = build(:workflow, config: {
                             'workflow' => {
                               'liquid_templates' => {
                                 'group_by' => nil,
                                 'sort_by' => ''
                               }
                             }
                           })
          expect(workflow).to be_valid
        end
      end
    end

    context 'connection section' do
      context 'when connection is not a hash' do
        it 'is invalid' do
          workflow = build(:workflow, config: {
                             'workflow' => { 'connection' => 'not a hash' }
                           })
          expect(workflow).not_to be_valid
          expect(workflow.errors[:config]).to include('workflow.connection must be a hash')
        end
      end

      context 'when connection has unknown keys' do
        it 'is invalid' do
          workflow = build(:workflow, config: {
                             'workflow' => {
                               'connection' => { 'unknown_key' => 'value' }
                             }
                           })
          expect(workflow).not_to be_valid
          expect(workflow.errors[:config]).to include('unexpected key in workflow.connection: unknown_key')
        end
      end

      context 'when connection has valid keys' do
        it 'is valid' do
          workflow = build(:workflow, config: {
                             'workflow' => {
                               'connection' => {
                                 'subdomain' => 'mycompany',
                                 'domain' => 'myapp.com'
                               }
                             }
                           })
          expect(workflow).to be_valid
        end
      end

      context 'when connection values are not strings' do
        it 'is invalid' do
          workflow = build(:workflow, config: {
                             'workflow' => {
                               'connection' => {
                                 'subdomain' => 123, # Should be string
                                 'domain' => ['array'] # Should be string
                               }
                             }
                           })
          expect(workflow).not_to be_valid
          expect(workflow.errors[:config]).to include('workflow.connection.subdomain must be a string')
          expect(workflow.errors[:config]).to include('workflow.connection.domain must be a string')
        end
      end

      context 'when connection values are nil' do
        it 'is valid' do
          workflow = build(:workflow, config: {
                             'workflow' => {
                               'connection' => {
                                 'subdomain' => nil,
                                 'domain' => nil
                               }
                             }
                           })
          expect(workflow).to be_valid
        end
      end
    end

    context 'when config has both valid sections' do
      it 'is valid' do
        workflow = build(:workflow, config: {
                           'workflow' => {
                             'liquid_templates' => {
                               'group_by' => '{{row.type}}',
                               'sort_by' => '{{row.order}}'
                             },
                             'connection' => {
                               'subdomain' => 'test',
                               'domain' => 'example.com'
                             }
                           }
                         })
        expect(workflow).to be_valid
      end
    end

    context 'when config allows unknown top-level sections' do
      it 'is valid (for shared config files)' do
        workflow = build(:workflow, config: {
                           'workflow' => {
                             'liquid_templates' => {
                               'group_by' => '{{row.type}}'
                             }
                           },
                           'steps' => {
                             'step_1' => { 'some' => 'config' }
                           },
                           'other_app_config' => {
                             'setting' => 'value'
                           }
                         })
        expect(workflow).to be_valid
      end
    end
  end

  describe '#create_execution' do
    let(:workflow) { create(:workflow) }
    let(:data_source) { create(:data_source) }

    it 'creates a workflow execution' do
      expect do
        workflow.create_execution(data_source)
      end.to change(WorkflowExecution, :count).by(1)
    end

    it 'returns the created execution' do
      execution = workflow.create_execution(data_source)
      expect(execution).to be_a(WorkflowExecution)
      expect(execution.workflow).to eq(workflow)
      expect(execution.data_source).to eq(data_source)
    end
  end
end
