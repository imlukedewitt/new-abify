require 'rails_helper'
require_relative '../../lib/data_utils'

RSpec.describe DataUtils do
  describe '.deep_stringify_keys' do
    it 'converts symbol keys to string keys' do
      input = { name: "John", age: 30 }
      expected = { "name" => "John", "age" => 30 }

      expect(DataUtils.deep_stringify_keys(input)).to eq(expected)
    end

    it 'handles nested hashes' do
      input = { user: { name: "John", profile: { age: 30 } } }
      expected = { "user" => { "name" => "John", "profile" => { "age" => 30 } } }

      expect(DataUtils.deep_stringify_keys(input)).to eq(expected)
    end

    it 'handles arrays with hashes' do
      input = [{ name: "John" }, { name: "Jane" }]
      expected = [{ "name" => "John" }, { "name" => "Jane" }]

      expect(DataUtils.deep_stringify_keys(input)).to eq(expected)
    end

    it 'handles non-hash values unchanged' do
      expect(DataUtils.deep_stringify_keys("string")).to eq("string")
      expect(DataUtils.deep_stringify_keys(123)).to eq(123)
      expect(DataUtils.deep_stringify_keys(nil)).to eq(nil)
    end
  end

  describe '.to_boolean' do
    context 'truthy values' do
      it 'returns true for "true"' do
        expect(DataUtils.to_boolean("true")).to be true
      end

      it 'handles case insensitive true values' do
        expect(DataUtils.to_boolean("TRUE")).to be true
        expect(DataUtils.to_boolean("True")).to be true
        expect(DataUtils.to_boolean("tRuE")).to be true
      end

      it 'handles whitespace around true values' do
        expect(DataUtils.to_boolean("  true  ")).to be true
        expect(DataUtils.to_boolean("\ttrue\n")).to be true
      end

      it 'returns true for "1"' do
        expect(DataUtils.to_boolean("1")).to be true
      end

      it 'returns true for "yes"' do
        expect(DataUtils.to_boolean("yes")).to be true
        expect(DataUtils.to_boolean("YES")).to be true
        expect(DataUtils.to_boolean("Yes")).to be true
      end

      it 'treats non-empty strings as truthy' do
        expect(DataUtils.to_boolean("anything")).to be true
        expect(DataUtils.to_boolean("hello world")).to be true
        expect(DataUtils.to_boolean("123")).to be true
      end

      it 'handles non-string truthy values' do
        expect(DataUtils.to_boolean(123)).to be true
        expect(DataUtils.to_boolean(true)).to be true
        expect(DataUtils.to_boolean([])).to be true
      end
    end

    context 'falsy values' do
      it 'returns false for "false"' do
        expect(DataUtils.to_boolean("false")).to be false
      end

      it 'handles case insensitive false values' do
        expect(DataUtils.to_boolean("FALSE")).to be false
        expect(DataUtils.to_boolean("False")).to be false
        expect(DataUtils.to_boolean("fAlSe")).to be false
      end

      it 'handles whitespace around false values' do
        expect(DataUtils.to_boolean("  false  ")).to be false
        expect(DataUtils.to_boolean("\tfalse\n")).to be false
      end

      it 'returns false for "0"' do
        expect(DataUtils.to_boolean("0")).to be false
      end

      it 'returns false for "no"' do
        expect(DataUtils.to_boolean("no")).to be false
        expect(DataUtils.to_boolean("NO")).to be false
        expect(DataUtils.to_boolean("No")).to be false
      end

      it 'returns false for empty string' do
        expect(DataUtils.to_boolean("")).to be false
      end

      it 'returns false for whitespace-only string' do
        expect(DataUtils.to_boolean("   ")).to be false
      end
    end
  end

  describe '.normalize_request_body' do
    it 'returns non-hash values unchanged' do
      expect(DataUtils.normalize_request_body("string")).to eq("string")
      expect(DataUtils.normalize_request_body(123)).to eq(123)
      expect(DataUtils.normalize_request_body(nil)).to eq(nil)
    end

    it 'removes keys with empty string values' do
      input = { "name" => "John", "email" => "", "phone" => "  " }
      expected = { "name" => "John" }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'removes keys with empty array strings' do
      input = { "name" => "John", "tags" => "[]" }
      expected = { "name" => "John" }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'removes keys with empty object strings' do
      input = { "name" => "John", "metadata" => "{}" }
      expected = { "name" => "John" }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'parses non-empty JSON array strings' do
      input = { "tags" => '["a", "b"]' }
      expected = { "tags" => ["a", "b"] }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'parses non-empty JSON object strings' do
      input = { "metadata" => '{"key": "value"}' }
      expected = { "metadata" => { "key" => "value" } }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'converts "true" string to boolean true' do
      input = { "active" => "true", "enabled" => "TRUE" }
      expected = { "active" => true, "enabled" => true }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'converts "false" string to boolean false' do
      input = { "active" => "false", "enabled" => "FALSE" }
      expected = { "active" => false, "enabled" => false }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'handles nested hashes' do
      input = {
        "subscription" => {
          "customer_id" => "123",
          "reference" => "",
          "import_mrr" => "true",
          "components" => "[]"
        }
      }
      expected = {
        "subscription" => {
          "customer_id" => "123",
          "import_mrr" => true
        }
      }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'removes empty nested hashes entirely' do
      input = {
        "name" => "John",
        "metadata" => { "field1" => "", "field2" => "  " }
      }
      expected = { "name" => "John" }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'keeps non-string values unchanged' do
      input = { "count" => 5, "active" => true, "rate" => 3.14 }
      expect(DataUtils.normalize_request_body(input)).to eq(input)
    end

    it 'keeps actual false boolean values' do
      input = { "active" => false }
      expected = { "active" => false }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end

    it 'handles malformed JSON strings gracefully' do
      input = { "data" => "[not valid json" }
      expected = { "data" => "[not valid json" }
      expect(DataUtils.normalize_request_body(input)).to eq(expected)
    end
  end

  describe '.parse_json_string' do
    it 'parses valid JSON arrays' do
      expect(DataUtils.parse_json_string('[1, 2, 3]')).to eq([1, 2, 3])
    end

    it 'parses valid JSON objects' do
      expect(DataUtils.parse_json_string('{"a": 1}')).to eq({ "a" => 1 })
    end

    it 'returns nil for empty arrays' do
      expect(DataUtils.parse_json_string('[]')).to be_nil
    end

    it 'returns nil for empty objects' do
      expect(DataUtils.parse_json_string('{}')).to be_nil
    end

    it 'converts true string to boolean' do
      expect(DataUtils.parse_json_string('true')).to be true
      expect(DataUtils.parse_json_string('TRUE')).to be true
    end

    it 'converts false string to boolean' do
      expect(DataUtils.parse_json_string('false')).to be false
      expect(DataUtils.parse_json_string('FALSE')).to be false
    end

    it 'returns regular strings unchanged' do
      expect(DataUtils.parse_json_string('hello')).to eq('hello')
      expect(DataUtils.parse_json_string('123')).to eq('123')
    end

    it 'handles whitespace' do
      expect(DataUtils.parse_json_string('  true  ')).to be true
      expect(DataUtils.parse_json_string('  [1, 2]  ')).to eq([1, 2])
    end

    it 'returns malformed JSON-like strings unchanged' do
      expect(DataUtils.parse_json_string('[invalid')).to eq('[invalid')
      expect(DataUtils.parse_json_string('{broken}')).to eq('{broken}')
    end
  end
end
