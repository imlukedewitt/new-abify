# frozen_string_literal: true

require_relative '../services/liquid/environment'

##
# Validates step configuration structure and content
# Expects config to be scoped to specific step: config['steps'][step_name] or direct step config
class StepConfigValidator
  attr_reader :config, :errors

  REQUIRED_KEYS = %w[
    name
    url
  ].freeze

  OPTIONAL_KEYS = %w[
    required
    method
    body
    params
    skip_condition
    success_data
  ].freeze

  ALLOWED_KEYS = (REQUIRED_KEYS + OPTIONAL_KEYS).freeze

  def initialize(config)
    @config = config
    @errors = []
    @environment = Liquid::EnvironmentBuilder.build
  end

  def valid?
    validate
    errors.empty?
  end

  def validate
    @errors = []

    unless config.is_a?(Hash)
      errors << 'step config must be a hash'
      return false
    end

    unless config.key?('liquid_templates') && config['liquid_templates'].is_a?(Hash)
      errors << 'step config must include liquid_templates hash'
      return false
    end

    validate_required_keys
    validate_allowed_keys
    validate_liquid_syntax

    errors.empty?
  end

  private

  def validate_required_keys
    liquid_templates = config['liquid_templates']

    REQUIRED_KEYS.each do |key|
      errors << "step config must include #{key} in liquid_templates" unless liquid_templates.key?(key)
    end
  end

  def validate_allowed_keys
    liquid_templates = config['liquid_templates']
    extra_keys = liquid_templates.keys - ALLOWED_KEYS

    extra_keys.each do |key|
      errors << "unexpected key in step liquid_templates: #{key}"
    end
  end

  def validate_liquid_syntax
    liquid_templates = config['liquid_templates']

    liquid_templates.each do |key, value|
      if value.is_a?(Hash)
        # Handle nested templates like success_data
        validate_nested_templates(value, "liquid_templates.#{key}")
      elsif value.is_a?(String) && !value.empty?
        validate_template_syntax(value, "liquid_templates.#{key}")
      end
    end
  end

  def validate_nested_templates(hash, parent_path)
    hash.each do |key, template|
      next unless template.is_a?(String) && !template.empty?

      validate_template_syntax(template, "#{parent_path}.#{key}")
    end
  end

  def validate_template_syntax(template, field_path)
    ::Liquid::Template.parse(template, environment: @environment)
  rescue ::Liquid::SyntaxError => e
    errors << "invalid Liquid syntax in #{field_path}: #{e.message}"
  rescue StandardError => e
    errors << "failed to validate Liquid syntax in #{field_path}: #{e.message}"
  end
end
