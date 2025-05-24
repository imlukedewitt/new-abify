# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepProcessor do
  let(:workflow) { create(:workflow) }
  let(:step) { create(:workflow_step, workflow: workflow) }
  let(:context) { { key: 'value' } }
  let(:step_processor) { described_class.new(step) }

  describe '#initialize' do
    it 'assigns the class variables' do
      expect(step_processor.step).to eq(step)
    end

    it 'raises an error when step is nil' do
      expect { described_class.new(nil, context) }.to raise_error(ArgumentError)
    end
  end

  describe '::call' do
    it 'initializes a new instance and calls execute' do
      step = create(:workflow_step)
      expect(described_class).to receive(:new)
        .with(step)
        .and_return(step_processor)
      expect(step_processor).to receive(:call)
      described_class.call(step)
    end
  end
end
