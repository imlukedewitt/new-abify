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

    it 'includes connection info' do
      expect(context).to include(
        subdomain: 'acme',
        domain: 'application.com',
        base_url: 'https://acme.application.com'
      )
    end

    context 'when workflow has custom domain settings' do
      before do
        workflow.config = {
          'connection' => {
            'subdomain' => 'custom',
            'domain' => 'test.com'
          }
        }
      end

      it 'uses workflow domain settings' do
        expect(context).to include(
          subdomain: 'custom',
          domain: 'test.com',
          base_url: 'https://custom.test.com'
        )
      end
    end

    context 'when workflow config is empty' do
      before do
        workflow.config = {}
      end

      it 'uses default values' do
        expect(context).to include(
          subdomain: 'acme',
          domain: 'application.com',
          base_url: 'https://acme.application.com'
        )
      end
    end
  end
end
