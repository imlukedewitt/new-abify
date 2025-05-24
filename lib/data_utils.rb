# frozen_string_literal: true

module DataUtils
  def self.deep_stringify_keys(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_s).transform_values { |v| deep_stringify_keys(v) }
    when Array
      obj.map { |v| deep_stringify_keys(v) }
    else
      obj
    end
  end

  def self.to_boolean(value)
    result = value.to_s.strip.downcase
    case result
    when "true", "1", "yes"
      true
    when "false", "0", "no", ""
      false
    else
      true
    end
  end
end