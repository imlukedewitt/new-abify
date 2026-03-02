# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Liquid::ContextBuilder do
  let(:workflow) { create(:workflow) }
  let(:row) { create(:row) }
  let(:context_builder) { described_class.new(row: row, workflow: workflow) }

  describe '#build' do
    subject(:context) { context_builder.build }

    it 'includes row data' do
      expect(context[:row]).to eq({ 'source_index' => row.source_index, **row.data })
    end

    context 'when workflow has a Connection model' do
      it 'includes connection info from the Connection model' do
        user = create(:user)
        connection = create(:connection, user: user, subdomain: 'mycompany', domain: 'salesforce.com')
        context_builder = described_class.new(row: row, workflow: workflow, connection: connection)
        context = context_builder.build

        expect(context).to include(
          'subdomain' => 'mycompany',
          'domain' => 'salesforce.com',
          'base_url' => 'https://mycompany.salesforce.com'
        )
      end
    end
  end
end
