# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepProcessor do
  let(:workflow) { create(:workflow) }
  let(:step) { create(:workflow_step, workflow: workflow) }
  let(:context) { { key: 'value' } }
  let(:executor) { described_class.new(step) }

  describe '#initialize' do
    it 'assigns the class variables' do
      expect(executor.step).to eq(step)
    end

    it 'raises an error when step is nil' do
      expect { described_class.new(nil, context) }.to raise_error(ArgumentError)
    end
  end
end
