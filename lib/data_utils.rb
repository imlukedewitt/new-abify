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

  def self.boolean?(value)
    value.is_a?(TrueClass) || value.is_a?(FalseClass)
  end

  # Normalizes a Liquid-rendered request body for API consumption.
  # Liquid templates output everything as strings, so this method:
  # - Removes keys with empty string values
  # - Removes keys with empty arrays/objects (rendered as "[]" or "{}")
  # - Converts "true"/"false" strings to booleans
  # - Parses JSON array/object strings into actual arrays/objects
  def self.normalize_request_body(body)
    return body unless body.is_a?(Hash)

    body.each_with_object({}) do |(key, value), result|
      normalized = normalize_value(value)
      result[key] = normalized unless normalized.nil?
    end
  end

  def self.normalize_value(value)
    case value
    when Hash
      normalized = value.each_with_object({}) do |(k, v), result|
        normalized_v = normalize_value(v)
        result[k] = normalized_v unless normalized_v.nil?
      end
      normalized.empty? ? nil : normalized
    when String
      return nil if value.strip.empty?
      parse_json_string(value)
    else
      value
    end
  end

  def self.parse_json_string(str)
    stripped = str.strip
    # Try to parse JSON arrays and objects
    if (stripped.start_with?('[') && stripped.end_with?(']')) ||
       (stripped.start_with?('{') && stripped.end_with?('}'))
      parsed = JSON.parse(stripped)
      # Return nil for empty arrays/objects
      return nil if parsed.empty?
      return parsed
    end
    # Convert boolean strings
    return true if stripped.downcase == 'true'
    return false if stripped.downcase == 'false'
    # Return original string
    str
  rescue JSON::ParserError
    str
  end
end
