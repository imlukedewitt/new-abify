# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConnectionSlotsValidator do
  describe '#valid?' do
    context 'when connection_slots is nil' do
      it 'is valid' do
        validator = described_class.new(nil)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'when connection_slots is not an array' do
      it 'is invalid' do
        validator = described_class.new('not an array')
        expect(validator.valid?).to be false
        expect(validator.errors).to include('connection_slots must be an array')
      end
    end

    context 'when connection_slots is an empty array' do
      it 'is valid' do
        validator = described_class.new([])
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'when connection_slots has valid slot structure' do
      let(:valid_slots) do
        [
          { 'handle' => 'target_crm', 'description' => 'Target CRM system', 'default' => true },
          { 'handle' => 'source_api', 'description' => 'Source API endpoint' }
        ]
      end

      it 'is valid' do
        validator = described_class.new(valid_slots)
        expect(validator.valid?).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'when slot is not a hash' do
      it 'is invalid' do
        validator = described_class.new(['string'])
        expect(validator.valid?).to be false
        expect(validator.errors).to include('slot at index 0 must be a hash')
      end
    end

    context 'when slot missing handle key' do
      it 'is invalid' do
        validator = described_class.new([{ 'description' => 'no handle' }])
        expect(validator.valid?).to be false
        expect(validator.errors).to include('slot at index 0 must have a \'handle\' key')
      end
    end

    context 'when slot handle has invalid format' do
      it 'is invalid' do
        validator = described_class.new([{ 'handle' => 'Invalid Handle' }])
        expect(validator.valid?).to be false
        expect(validator.errors).to include(
          'slot at index 0 handle \'Invalid Handle\' must start with a letter and contain only lowercase letters, numbers, hyphens, and underscores'
        )
      end
    end

    context 'when slot has unexpected key' do
      it 'is invalid' do
        validator = described_class.new([{ 'handle' => 'valid', 'extra' => 'key' }])
        expect(validator.valid?).to be false
        expect(validator.errors).to include(
          'slot at index 0 has unexpected key \'extra\' (allowed: handle, description, default)'
        )
      end
    end

    context 'when slot description is not a string' do
      it 'is invalid' do
        validator = described_class.new([{ 'handle' => 'valid', 'description' => 123 }])
        expect(validator.valid?).to be false
        expect(validator.errors).to include('slot at index 0 description must be a string')
      end
    end

    context 'when slot default is not a boolean' do
      it 'is invalid' do
        validator = described_class.new([{ 'handle' => 'valid', 'default' => 'yes' }])
        expect(validator.valid?).to be false
        expect(validator.errors).to include('slot at index 0 default must be a boolean')
      end
    end

    context 'when duplicate handles exist' do
      it 'is invalid' do
        validator = described_class.new([
                                          { 'handle' => 'duplicate' },
                                          { 'handle' => 'duplicate' }
                                        ])
        expect(validator.valid?).to be false
        expect(validator.errors).to include('slot handle \'duplicate\' is duplicated')
      end
    end
  end
end
