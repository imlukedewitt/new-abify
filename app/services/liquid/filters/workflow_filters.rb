# frozen_string_literal: true

# custom filters to use in workflow liquid templates
module WorkflowFilters
  def present?(value)
    case value
    when nil
      false
    when String
      !value.strip.empty?
    when Numeric, TrueClass, FalseClass
      true
    when Array, Hash
      !value.empty?
    else
      true
    end
  end

  def blank?(value)
    !present?(value)
  end
end
