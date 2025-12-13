# frozen_string_literal: true

# Helper to build step_templates hash for tests
module StepTemplatesHelper
  def build_step_templates(workflow)
    workflow.steps.each_with_object({}) do |step, hash|
      hash[step.id] = Liquid::StepTemplates.new(step.step_config['liquid_templates'])
    end
  end

  def build_step_templates_for(step)
    { step.id => Liquid::StepTemplates.new(step.step_config['liquid_templates']) }
  end
end

RSpec.configure do |config|
  config.include StepTemplatesHelper
end
