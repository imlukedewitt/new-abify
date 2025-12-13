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
      expect(step.errors[:config]).to include('step config must include name in liquid_templates')
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

end
