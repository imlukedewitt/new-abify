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

        expect(context).to include(
          'subdomain' => 'mycompany',
          'domain' => 'salesforce.com',
          'base_url' => 'https://mycompany.salesforce.com'
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

      it 'does not include connection info' do
        connection_keys = %w[domain subdomain base_url]
        expect(context.keys.map(&:to_s)).not_to include(*connection_keys)
      end
    end
  end
end
