# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Liquid::ContextBuilder do
  let(:workflow) { create(:workflow) }
  let(:row) { create(:row) }
  let(:context_builder) { described_class.new(row: row, workflow: workflow) }

  describe '#build' do
    subject(:context) { context_builder.build }

    it 'includes row data' do
      expect(context[:row]).to eq({ "source_index" => row.source_index, **row.data })
    end

    context 'when workflow has a Connection model' do
      it 'includes connection info from the Connection model' do
        user = create(:user)
        connection = create(:connection, user: user, subdomain: 'mycompany', domain: 'salesforce.com')
        workflow_with_connection = create(:workflow, connection: connection)
        context_builder = described_class.new(row: row, workflow: workflow_with_connection)
        context = context_builder.build

        expect(context[:connection]).to eq(
          'subdomain' => 'mycompany',
          'domain' => 'salesforce.com',
          'base_url' => 'https://mycompany.salesforce.com'
        )
      end
    end

    context 'when workflow has custom domain settings in config' do
      before do
        workflow.config = {
          'connection' => {
            'subdomain' => 'custom',
            'domain' => 'test.com'
          }
        }
      end

      it 'uses workflow config domain settings' do
        expect(context[:connection]).to eq(
          'subdomain' => 'custom',
          'domain' => 'test.com',
          'base_url' => 'https://custom.test.com'
        )
      end
    end

    context 'when workflow has incomplete config connection' do
      before do
        workflow.config = {
          'connection' => {
            'subdomain' => 'custom'
            # missing domain
          }
        }
      end

      it 'returns empty connection hash' do
        expect(context[:connection]).to eq({})
      end
    end

    context 'when workflow config is empty' do
      before do
        workflow.config = {}
      end

      it 'returns empty connection hash' do
        expect(context[:connection]).to eq({})
      end
    end
  end
end
