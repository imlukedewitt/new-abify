# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowSerializer do
  let(:workflow) { create(:workflow) }
  let(:serializer) { described_class.new(workflow) }
  let(:serialization) { serializer.as_json }

  it 'serializes the workflow' do
    expect(serialization).to eq(
      {
        id: workflow.id,
        name: workflow.name,
        created_at: workflow.created_at.as_json,
        updated_at: workflow.updated_at.as_json
      }
    )
  end

  context 'when include_steps is true' do
    let(:workflow) { create(:workflow, :with_steps) }
    let(:serializer) { described_class.new(workflow, include_steps: true) }

    it 'includes the steps' do
      expect(serialization[:steps]).to be_present
      expect(serialization[:steps].count).to eq(3)
    end
  end

  context 'when include_config is true' do
    let(:serializer) { described_class.new(workflow, include_config: true) }

    it 'includes the config' do
      expect(serialization[:config]).to be_present
    end
  end
end