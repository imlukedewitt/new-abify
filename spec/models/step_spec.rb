# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Step, type: :model do
  describe 'associations' do
    it 'has many step_executions' do
      association = described_class.reflect_on_association(:step_executions)
      expect(association.macro).to eq :has_many
      expect(association.options[:dependent]).to eq :destroy
    end
  end

  describe '#initialize' do
    let(:step) { create(:step) }

    it 'creates a new Step with valid attributes' do
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

  describe '#set_default_order' do
    let(:workflow) { create(:workflow) }
    let(:step_config) do
      { 'liquid_templates' => { 'name' => 'test', 'url' => 'http://example.com' } }
    end

    it 'auto-increments order for steps created individually' do
      step1 = create(:step, workflow: workflow, order: nil)
      step2 = create(:step, workflow: workflow, order: nil)
      step3 = create(:step, workflow: workflow, order: nil)

      expect(step1.order).to eq(1)
      expect(step2.order).to eq(2)
      expect(step3.order).to eq(3)
    end

    it 'auto-increments order for steps created via nested attributes' do
      workflow = Workflow.create!(
        name: 'Test Workflow',
        steps_attributes: [
          { name: 'Step A', config: step_config },
          { name: 'Step B', config: step_config },
          { name: 'Step C', config: step_config }
        ]
      )

      orders = workflow.steps.order(:order).pluck(:name, :order)
      expect(orders).to eq([['Step A', 1], ['Step B', 2], ['Step C', 3]])
    end
  end

  describe '#config' do
    it 'validates config is present and is a hash' do
      step = build(:step, config: 'not a hash')
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include('must be a hash')

      step = build(:step, config: nil)
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include("can't be blank")

      step = build(:step, config: {})
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include("can't be blank")
    end

    it 'validates liquid_templates is present in config' do
      step = build(:step, config: { foo: 'bar' })
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include('step config must include liquid_templates hash')
    end

    it 'validates required liquid_template fields' do
      step = build(:step, config: { 'liquid_templates' => {} })
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include('step config must include url in liquid_templates')
    end

    it 'checks for unsupported keys in liquid_templates' do
      step = build(:step, config: {
                     'liquid_templates' => {
                       'name' => '1',
                       'url' => '{{base_url}}/customers/lookup.json?reference={{row.customer_reference}}',
                       'unsupported_key' => 'value'
                     }
                   })
      expect(step).not_to be_valid
      expect(step.errors[:config]).to include('unexpected key in step liquid_templates: unsupported_key')
    end
  end

  describe '#normalize_config' do
    let(:workflow) { create(:workflow) }

    it 'parses success_data from JSON string' do
      step = build(:step, workflow: workflow, config: {
                     'liquid_templates' => { 'name' => 'test', 'url' => 'http://example.com', 'success_data' => '{"foo":"bar"}' }
                   })
      step.valid?
      expect(step.config['liquid_templates']['success_data']).to eq({ 'foo' => 'bar' })
    end

    it 'keeps success_data as string if not valid JSON' do
      step = build(:step, workflow: workflow, config: {
                     'liquid_templates' => { 'name' => 'test', 'url' => 'http://example.com', 'success_data' => 'not json' }
                   })
      step.valid?
      expect(step.config['liquid_templates']['success_data']).to eq('not json')
    end

    it 'coerces required string "true" to boolean' do
      step = build(:step, workflow: workflow, config: {
                     'liquid_templates' => { 'name' => 'test', 'url' => 'http://example.com', 'required' => 'true' }
                   })
      step.valid?
      expect(step.config['liquid_templates']['required']).to eq(true)
    end

    it 'coerces required to false when not "true"' do
      step = build(:step, workflow: workflow, config: {
                     'liquid_templates' => { 'name' => 'test', 'url' => 'http://example.com', 'required' => 'false' }
                   })
      step.valid?
      expect(step.config['liquid_templates']['required']).to eq(false)
    end

    it 'copies name to liquid_templates if blank' do
      step = build(:step, name: 'My Step', workflow: workflow, config: {
                     'liquid_templates' => { 'url' => 'http://example.com' }
                   })
      step.valid?
      expect(step.config['liquid_templates']['name']).to eq('My Step')
    end

    it 'does not overwrite existing liquid_templates name' do
      step = build(:step, name: 'My Step', workflow: workflow, config: {
                     'liquid_templates' => { 'name' => 'Existing Name', 'url' => 'http://example.com' }
                   })
      step.valid?
      expect(step.config['liquid_templates']['name']).to eq('Existing Name')
    end
  end
end
