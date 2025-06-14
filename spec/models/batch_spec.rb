require 'rails_helper'

RSpec.describe Batch, type: :model do
  describe 'attributes' do
    it 'can have its processing_mode initialized to "sequential"' do
      batch = Batch.new(processing_mode: "sequential")
      expect(batch.processing_mode).to eq("sequential")
    end

    it 'can have its processing_mode initialized to "parallel"' do
      batch = Batch.new(processing_mode: "parallel")
      expect(batch.processing_mode).to eq("parallel")
    end

    it 'defaults to a "sequential" processing_mode when not specified' do
      batch = Batch.new
      expect(batch.processing_mode).to eq("sequential")
    end
  end

  describe 'validations' do
    it 'only allows processing_mode to be "sequential" or "parallel"' do
      valid_batch1 = Batch.new(processing_mode: "sequential")
      valid_batch2 = Batch.new(processing_mode: "parallel")
      invalid_batch = Batch.new(processing_mode: "invalid_value")

      expect(valid_batch1).to be_valid
      expect(valid_batch2).to be_valid
      expect(invalid_batch).not_to be_valid
      expect(invalid_batch.errors[:processing_mode]).to be_present
    end
  end
end
