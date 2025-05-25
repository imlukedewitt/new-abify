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
end
