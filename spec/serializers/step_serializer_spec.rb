# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepSerializer do
  let(:step) { create(:step) }
  let(:serializer) { described_class.new(step) }
  let(:serialization) { serializer.as_json }

  it 'serializes the step' do
    expect(serialization).to eq(
      {
        id: step.id,
        name: step.name,
        order: step.order
      }
    )
  end
end
