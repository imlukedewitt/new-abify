module WorkflowFilters
  def present?(value)
    case value
    when nil
      false
    when String
      !value.strip.empty?
    when Array, Hash
      !value.empty?
    else
      true
    end
  end
end