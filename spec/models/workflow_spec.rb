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

    it 'belongs to connection (optional)' do
      association = described_class.reflect_on_association(:connection)
      expect(association.macro).to eq :belongs_to
      expect(association.options[:optional]).to eq true
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      workflow = build(:workflow, name: nil)
      expect(workflow).not_to be_valid
      expect(workflow.errors[:name]).to include("can't be blank")
    end

    describe 'handle' do
      it 'allows nil handle' do
        workflow = build(:workflow, handle: nil)
        expect(workflow).to be_valid
      end

      it 'allows valid handle' do
        workflow = build(:workflow, handle: 'my-workflow-123')
        expect(workflow).to be_valid
      end

      it 'requires handle to start with a letter' do
        workflow = build(:workflow, handle: '123-workflow')
        expect(workflow).not_to be_valid
        expect(workflow.errors[:handle]).to include('must start with a letter and contain only lowercase letters, numbers, hyphens, and underscores')
      end

      it 'rejects uppercase letters' do
        workflow = build(:workflow, handle: 'MyWorkflow')
        expect(workflow).not_to be_valid
      end

      it 'rejects spaces' do
        workflow = build(:workflow, handle: 'my workflow')
        expect(workflow).not_to be_valid
      end

      it 'enforces uniqueness' do
        create(:workflow, handle: 'unique-handle')
        workflow = build(:workflow, handle: 'unique-handle')
        expect(workflow).not_to be_valid
        expect(workflow.errors[:handle]).to include('has already been taken')
      end
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

  describe '#resolved_auth_config' do
    let(:user) { create(:user) }

    context 'when workflow has a connection' do
      it 'returns the connection credentials' do
        connection = create(:connection, user: user, credentials: { type: 'bearer', token: 'conn_token' })
        workflow = create(:workflow, connection: connection)

        expect(workflow.resolved_auth_config).to eq({ 'type' => 'bearer', 'token' => 'conn_token' })
      end
    end

    context 'when workflow has no connection but has auth in config' do
      it 'returns auth from config (backwards compatibility)' do
        workflow = create(:workflow, config: {
                            'connection' => {
                              'auth' => { 'type' => 'basic', 'username' => 'user', 'password' => 'pass' }
                            }
                          })

        expect(workflow.resolved_auth_config).to eq({ 'type' => 'basic', 'username' => 'user', 'password' => 'pass' })
      end
    end

    context 'when workflow has both connection and config auth' do
      it 'prioritizes connection over config' do
        connection = create(:connection, user: user, credentials: { type: 'bearer', token: 'conn_token' })
        workflow = create(:workflow, connection: connection, config: {
                            'connection' => {
                              'auth' => { 'type' => 'basic', 'username' => 'user', 'password' => 'pass' }
                            }
                          })

        expect(workflow.resolved_auth_config).to eq({ 'type' => 'bearer', 'token' => 'conn_token' })
      end
    end

    context 'when workflow has neither connection nor config auth' do
      it 'returns empty hash' do
        workflow = create(:workflow, config: nil)

        expect(workflow.resolved_auth_config).to eq({})
      end

      it 'returns empty hash when config has no auth' do
        workflow = create(:workflow, config: { 'connection' => { 'subdomain' => 'test' } })

        expect(workflow.resolved_auth_config).to eq({})
      end
    end
  end

  describe 'connection deletion behavior' do
    let(:user) { create(:user) }

    it 'nullifies connection_id when connection is deleted' do
      connection = create(:connection, user: user)
      workflow = create(:workflow, connection: connection)

      expect(workflow.connection_id).not_to be_nil

      connection.destroy

      workflow.reload
      expect(workflow.connection_id).to be_nil
    end
  end

  describe '.find_by_id_or_handle' do
    let!(:workflow) { create(:workflow, :with_handle) }

    context 'when identifier is a numeric ID' do
      it 'finds by ID' do
        result = described_class.find_by_id_or_handle(workflow.id)
        expect(result).to eq(workflow)
      end

      it 'finds by ID as string' do
        result = described_class.find_by_id_or_handle(workflow.id.to_s)
        expect(result).to eq(workflow)
      end
    end

    context 'when identifier is a handle' do
      it 'finds by handle' do
        result = described_class.find_by_id_or_handle(workflow.handle)
        expect(result).to eq(workflow)
      end
    end

    context 'when identifier is blank' do
      it 'returns nil for nil' do
        expect(described_class.find_by_id_or_handle(nil)).to be_nil
      end

      it 'returns nil for empty string' do
        expect(described_class.find_by_id_or_handle('')).to be_nil
      end
    end

    context 'when identifier does not match' do
      it 'returns nil for non-existent ID' do
        expect(described_class.find_by_id_or_handle(99999)).to be_nil
      end

      it 'returns nil for non-existent handle' do
        expect(described_class.find_by_id_or_handle('nonexistent')).to be_nil
      end
    end
  end

  describe '.find_by_id_or_handle!' do
    let!(:workflow) { create(:workflow, :with_handle) }

    it 'returns workflow when found' do
      expect(described_class.find_by_id_or_handle!(workflow.handle)).to eq(workflow)
    end

    it 'raises RecordNotFound when not found' do
      expect do
        described_class.find_by_id_or_handle!('nonexistent')
      end.to raise_error(ActiveRecord::RecordNotFound, /Couldn't find Workflow with identifier=nonexistent/)
    end
  end
end
