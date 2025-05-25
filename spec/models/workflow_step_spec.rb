# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkflowStep, type: :model do
  describe '#initialize' do
    let(:step) { create(:workflow_step) }

    it 'creates a new WorkflowStep with valid attributes' do
      expect(step).to be_valid
      expect(step.name).to be_a(String)
      expect(step.order).to be_a(Integer)
      expect(step.config).to be_a(Hash)
    end

    it 'validates presence of name' do
      step.name = nil
      expect(step).not_to be_valid
      expect(step.errors[:name]).to include("can't be blank")
    end

    it 'validates presence of order' do
      step.order = nil
      expect(step).not_to be_valid
      expect(step.errors[:order]).to include("can't be blank")
    end

    it 'validates order is a positive integer' do
      step.order = -1
      expect(step).not_to be_valid
      expect(step.errors[:order]).to include('must be greater than 0')
    end
  end

  describe '#config' do
    it 'validates config is present and is a hash' do
      step = build(:workflow_step, config: 'not a hash')
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include('must be a hash')

      step = build(:workflow_step, config: nil)
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include("can't be blank")

      step = build(:workflow_step, config: {})
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include("can't be blank")
    end

    it 'validates liquid_templates is present in config' do
      step = build(:workflow_step, config: { foo: 'bar' })
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include('must include liquid_templates hash')
    end

    it 'validates required liquid_template fields' do
      step = build(:workflow_step, config: { 'liquid_templates' => {} })
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include('must include name')
      expect(step.errors[:config]).to include('must include url')
    end

    it 'checks for unsupported keys in liquid_templates' do
      step = build(:workflow_step, config: {
                     'liquid_templates' => {
                       'name' => '1',
                       'url' => '{{base_url}}/customers/lookup.json?reference={{row.customer_reference}}',
                       'unsupported_key' => 'value'
                     }
                   })
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include('unexpected key in liquid_templates: unsupported_key')
    end
  end

  describe '#process' do
    let(:step) { create(:workflow_step) }
    let(:row) { create(:row) }

    it 'calls the service StepProcessor' do
      expect(StepProcessor).to receive(:call).with(step, row)
      step.process(row)
    end
  end
end
