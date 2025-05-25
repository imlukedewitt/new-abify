# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StepProcessor do
  let(:workflow) { create(:workflow) }
  let(:step) { create(:workflow_step, workflow: workflow) }
  let(:row) { create(:row) }
  let(:step_processor) { described_class.new(step, row) }

  describe '#initialize' do
    it 'assigns the class variables' do
      expect(step_processor.step).to eq(step)
      expect(step_processor.row).to eq(row)
    end

    it 'raises an error when step is nil' do
      expect { described_class.new(nil, row) }.to raise_error(ArgumentError)
    end

    it 'raises an error when row is nil' do
      expect { described_class.new(step, nil) }.to raise_error(ArgumentError)
    end
  end

  describe '::call' do
    it 'initializes a new instance and calls execute' do
      step = create(:workflow_step)
      row = create(:row)
      expect(described_class).to receive(:new)
        .with(step, row)
        .and_return(step_processor)
      expect(step_processor).to receive(:call)
      described_class.call(step, row)
    end
  end

  describe '#should_skip?' do
    it 'returns false when no skip_condition is configured' do
      expect(step_processor.should_skip?).to be false
    end

    it 'evaluates skip_condition and returns boolean result' do
      step.config = { skip_condition: "{{row.email | present?}}" }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.should_skip?).to be true
    end

    it 'returns false when skip_condition evaluates to false' do
      step.config = { skip_condition: "{{row.email | blank?}}" }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.should_skip?).to be false
    end
  end

  describe '#process_template_field' do
    it 'processes URL with Liquid templates' do
      step.config = {
        'liquid_templates' => {
          'url' => 'https://api.example.com/users/{{row.first_name}}/{{row.last_name}}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.process_template_field('url')).to eq('https://api.example.com/users/John/Doe')
    end

    it 'handles missing variables in URL template' do
      step.config = {
        'liquid_templates' => {
          'url' => 'https://api.example.com/users/{{row.missing_field}}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.process_template_field('url')).to eq('https://api.example.com/users/')
    end

    it 'processes method with Liquid templates' do
      step.config = {
        'liquid_templates' => {
          'method' => '{{ row.http_method | default: "get" }}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.process_template_field('method')).to eq('get')

      # Create a new row with updated data
      updated_row = create(:row, data: row.data.merge('http_method' => 'post'))
      step_processor = StepProcessor.new(step, updated_row)
      expect(step_processor.process_template_field('method')).to eq('post')
    end

    it 'processes body with Liquid templates' do
      step.config = {
        'liquid_templates' => {
          'body' => '{"user":{"name":"{{row.first_name}} {{row.last_name}}","organization":"{{row.organization}}"}}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.process_template_field('body')).to eq('{"user":{"name":"John Doe","organization":"Acme Corp"}}')
    end

    it 'processes params with Liquid templates' do
      step.config = {
        'liquid_templates' => {
          'params' => '{"email":"{{row.email}}","reference":"{{row.reference | default: "unknown"}}"}'
        }
      }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.process_template_field('params')).to eq('{"email":"john.doe@example.com","reference":"unknown"}')
    end

    it 'returns nil when template field is not configured' do
      step.config = { 'liquid_templates' => { 'url' => 'https://example.com' } }
      step_processor = StepProcessor.new(step, row)

      expect(step_processor.process_template_field('nonexistent')).to be_nil
    end
  end
end
