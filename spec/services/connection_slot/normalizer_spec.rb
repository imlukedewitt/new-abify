# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConnectionSlot::Normalizer do
  describe '.call' do
    subject(:normalized) { described_class.call(input) }

    context 'when input is nil' do
      let(:input) { nil }

      it 'returns an empty array' do
        expect(normalized).to eq([])
      end
    end

    context 'when input is an empty hash' do
      let(:input) { {} }

      it 'returns an empty array' do
        expect(normalized).to eq([])
      end
    end

    context 'when input is a Rails-style hash of hashes (ActionController::Parameters)' do
      let(:input) do
        ActionController::Parameters.new(
          '0' => { 'handle' => ' primary ', 'description' => 'Main connection', 'default' => '1' },
          '1' => { 'handle' => 'secondary', 'description' => 'Backup', 'default' => '0' },
          '2' => { 'handle' => '', 'description' => 'empty handle' }
        ).permit!
      end

      it 'converts to a normalized array and filters out empty handles and false/blank values' do
        expect(normalized).to eq([
                                   { 'handle' => 'primary', 'description' => 'Main connection', 'default' => true },
                                   { 'handle' => 'secondary', 'description' => 'Backup' }
                                 ])
      end
    end

    context 'when input is an array of hashes' do
      let(:input) do
        [
          { 'handle' => 'api', 'default' => 'true' },
          { 'handle' => 'db', 'description' => 'Database' }
        ]
      end

      it 'normalizes each item in the array and removes sparse defaults' do
        expect(normalized).to eq([
                                   { 'handle' => 'api', 'default' => true },
                                   { 'handle' => 'db', 'description' => 'Database' }
                                 ])
      end
    end

    describe 'boolean casting' do
      it 'casts various truthy values to true' do
        expect(described_class.call([{ handle: 's', default: '1' }]).first['default']).to be true
        expect(described_class.call([{ handle: 's', default: 'true' }]).first['default']).to be true
        expect(described_class.call([{ handle: 's', default: true }]).first['default']).to be true
      end

      it 'omits the default key for various falsy values' do
        expect(described_class.call([{ handle: 's', default: '0' }]).first).not_to have_key('default')
        expect(described_class.call([{ handle: 's', default: 'false' }]).first).not_to have_key('default')
        expect(described_class.call([{ handle: 's', default: false }]).first).not_to have_key('default')
        expect(described_class.call([{ handle: 's', default: nil }]).first).not_to have_key('default')
      end
    end

    describe 'string sanitization' do
      let(:input) { [{ 'handle' => "  trimmed-handle  \n", 'description' => '  trimmed description  ' }] }

      it 'strips whitespace from handles and descriptions' do
        expect(normalized.first['handle']).to eq('trimmed-handle')
        expect(normalized.first['description']).to eq('trimmed description')
      end
    end

    describe 'filtering' do
      it 'removes items that are not hashes' do
        input = ['not a hash', { handle: 'valid' }]
        expect(described_class.call(input)).to eq([{ 'handle' => 'valid' }])
      end

      it 'removes items with blank handles' do
        input = [{ handle: '' }, { handle: '  ' }, { handle: nil }]
        expect(described_class.call(input)).to eq([])
      end
    end

    context 'with indifferent access' do
      it 'handles symbol keys correctly' do
        input = [{ handle: 'symbol-key', default: true }]
        expect(described_class.call(input).first['handle']).to eq('symbol-key')
      end

      it 'handles string keys correctly' do
        input = [{ 'handle' => 'string-key', 'default' => true }]
        expect(described_class.call(input).first['handle']).to eq('string-key')
      end
    end
  end
end
