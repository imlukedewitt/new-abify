# frozen_string_literal: true

# StepSerializer
# Serializes a step object
#
# @param [Step] step The step to serialize
# @return [Hash] The serialized step
class StepSerializer
  def initialize(step)
    @step = step
  end

  def as_json(_options = {})
    {
      id: @step.id,
      name: @step.name,
      order: @step.order
    }
  end
end
