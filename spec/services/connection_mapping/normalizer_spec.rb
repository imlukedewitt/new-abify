# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConnectionMapping::Normalizer do
  let(:user) { create(:user) }
  let(:connection) { create(:connection, user: user, name: 'Chargify', handle: 'chargify') }
  let(:workflow) do
    create(:workflow, connection_slots: [
             { 'handle' => 'billing', 'description' => 'Billing system' }
           ])
  end

  before do
    Current.user = user
  end

  describe '.call' do
    it 'enriches raw mappings with connection name and handle' do
      raw_mappings = {
        'billing' => { 'connection_id' => connection.id.to_s }
      }

      result = described_class.call(workflow: workflow, raw_mappings: raw_mappings)

      expect(result['billing']).to include(
        'connection_id' => connection.id.to_s,
        'connection_name' => 'Chargify',
        'connection_handle' => 'chargify'
      )
    end

    it 'returns empty hash if mappings are blank' do
      expect(described_class.call(workflow: workflow, raw_mappings: nil)).to eq({})
    end
  end
end
