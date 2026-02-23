# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConnectionSlot::Resolver do
  let(:user) { create(:user) }
  let(:workflow) do
    create(:workflow, connection_slots: [
             { 'handle' => 'primary', 'description' => 'Main connection' },
             { 'handle' => 'secondary', 'description' => 'Backup connection', 'default' => true }
           ])
  end
  let(:connection1) { create(:connection, user: user, name: 'Conn 1') }
  let(:connection2) { create(:connection, user: user, name: 'Conn 2') }

  let(:connection_mappings) do
    {
      'primary' => {
        'connection_id' => connection1.id,
        'connection_name' => connection1.name,
        'connection_handle' => connection1.handle
      },
      'secondary' => {
        'connection_id' => connection2.id,
        'connection_name' => connection2.name,
        'connection_handle' => connection2.handle
      }
    }
  end

  subject(:resolver) { described_class.new(workflow: workflow, connection_mappings: connection_mappings) }

  before do
    allow(Current).to receive(:user).and_return(user)
  end

  describe '#call' do
    subject(:result) { resolver.call }

    context 'when all mappings are valid' do
      it 'returns resolved connections and no errors' do
        expect(result[:connections]).to eq({
                                             'primary' => connection1,
                                             'secondary' => connection2
                                           })
        expect(result[:errors]).to be_empty
      end
    end

    context 'when a mapping references a connection the user does not own' do
      let(:other_user) { create(:user) }
      let(:other_connection) { create(:connection, user: other_user) }
      let(:connection_mappings) do
        {
          'primary' => {
            'connection_id' => other_connection.id,
            'connection_name' => other_connection.name,
            'connection_handle' => other_connection.handle
          }
        }
      end

      it 'returns a not found error for the specific slot' do
        expect(result[:errors]).to include("Connection for slot 'primary' not found")
        expect(result[:connections]['primary']).to be_nil
      end
    end

    context 'when a mapping references a non-existent slot' do
      let(:connection_mappings) do
        {
          'invalid_slot' => {
            'connection_id' => connection1.id,
            'connection_name' => connection1.name,
            'connection_handle' => connection1.handle
          }
        }
      end

      it 'returns an error for the invalid slot' do
        expect(result[:errors]).to include("Mapping references a slot 'invalid_slot' that does not exist in the workflow")
      end
    end

    context 'when a required slot is missing a mapping' do
      let(:connection_mappings) { {} }

      it 'returns an error for the missing mapping' do
        expect(result[:errors]).to include("Missing mapping for slot 'primary'")
        expect(result[:errors]).to include("Missing mapping for slot 'secondary'")
      end
    end

    context 'when a mapped connection does not exist' do
      let(:connection_mappings) do
        {
          'primary' => {
            'connection_id' => 999_999,
            'connection_name' => 'Non-existent',
            'connection_handle' => 'non-existent'
          }
        }
      end

      it 'returns an error for the missing connection' do
        expect(result[:errors]).to include("Connection for slot 'primary' not found")
      end
    end
  end
end
