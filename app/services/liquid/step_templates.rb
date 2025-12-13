# frozen_string_literal: true

require_relative 'environment'
require_relative '../../../lib/data_utils'

module Liquid
  # Pre-parses and renders step-level Liquid templates
  # Parses all templates on initialization for validation and performance
  class StepTemplates
    attr_reader :templates

    def initialize(liquid_templates)
      @liquid_templates = liquid_templates || {}
      @templates = {}
      @environment = EnvironmentBuilder.build
      parse_all
    end

    # Renders request fields (url, method, body, params)
    # @param context [Hash] The Liquid context with row/connection data
    # @return [Hash] Rendered request fields
    def render_request(context)
      {
        url: render(:url, context),
        method: render(:method, context),
        body: render(:body, context),
        params: render(:params, context)
      }.compact
    end

    # Evaluates skip_condition template as boolean
    # @param context [Hash] The Liquid context
    # @return [Boolean]
    def skip?(context)
      render_boolean(:skip_condition, context)
    end

    # Evaluates required template as boolean
    # @param context [Hash] The Liquid context
    # @return [Boolean]
    def required?(context)
      render_boolean(:required, context)
    end

    # Extracts success data by rendering each template in success_data hash
    # @param context [Hash] The Liquid context (should include response)
    # @param required [Boolean] Whether to raise on extraction failures
    # @return [Hash] Rendered success data
    def extract_success_data(context, required: false)
      return {} unless @templates[:success_data]

      stringify_context = DataUtils.deep_stringify_keys(context)

      @templates[:success_data].each_with_object({}) do |(key, template), result|
        result[key] = template.render(stringify_context)
      rescue StandardError => e
        raise "Failed to extract required success data '#{key}': #{e.message}" if required

        result[key] = nil
      end
    end

    private

    def parse_all
      @liquid_templates.each do |key, value|
        if value.is_a?(Hash)
          @templates[key.to_sym] = parse_hash(value)
        elsif value.is_a?(String) && !value.empty?
          @templates[key.to_sym] = parse(value)
        elsif DataUtils.boolean?(value)
          @templates[key.to_sym] = value
        end
      end
    end

    def parse_hash(hash)
      hash.transform_values { |template| parse(template) if template.is_a?(String) }.compact
    end

    def parse(template_string)
      ::Liquid::Template.parse(template_string, environment: @environment)
    end

    def render(key, context)
      template = @templates[key]
      return nil unless template

      return template.to_s if DataUtils.boolean?(template)

      stringify_context = DataUtils.deep_stringify_keys(context)
      template.render(stringify_context)
    end

    def render_boolean(key, context)
      template = @templates[key]

      return template if DataUtils.boolean?(template)

      result = render(key, context)
      return false if result.nil?

      DataUtils.to_boolean(result)
    end
  end
end
