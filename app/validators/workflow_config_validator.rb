# frozen_string_literal: true

##
# Validates workflow configuration structure and content
# Expects config to be scoped to workflow section: config['workflow']
class WorkflowConfigValidator
  attr_reader :config, :errors

  ALLOWED_SECTIONS = %w[
    liquid_templates
    connection
  ].freeze

  LIQUID_TEMPLATE_KEYS = %w[
    group_by
    sort_by
  ].freeze

  CONNECTION_KEYS = %w[
    subdomain
    domain
  ].freeze

  def initialize(config)
    @config = config
    @errors = []
  end

  def valid?
    validate
    errors.empty?
  end

  def validate
    @errors = []

    return true if config.nil?

    unless config.is_a?(Hash)
      errors << 'workflow config must be a hash'
      return false
    end

    validate_allowed_sections
    validate_liquid_templates_section if config.key?('liquid_templates')
    validate_connection_section if config.key?('connection')

    errors.empty?
  end

  private

  def validate_allowed_sections
    extra_sections = config.keys - ALLOWED_SECTIONS
    extra_sections.each { |section| errors << "unexpected section in workflow config: #{section}" }
  end

  def validate_liquid_templates_section
    liquid_templates = config['liquid_templates']

    unless liquid_templates.is_a?(Hash)
      errors << 'workflow.liquid_templates must be a hash'
      return
    end

    validate_liquid_templates_keys(liquid_templates)
    validate_liquid_templates_syntax(liquid_templates)
  end

  def validate_connection_section
    connection = config['connection']

    unless connection.is_a?(Hash)
      errors << 'workflow.connection must be a hash'
      return
    end

    validate_connection_keys(connection)
    validate_connection_values(connection)
  end

  def validate_liquid_templates_keys(liquid_templates)
    extra_keys = liquid_templates.keys - LIQUID_TEMPLATE_KEYS
    extra_keys.each { |key| errors << "unexpected key in workflow.liquid_templates: #{key}" }
  end

  def validate_liquid_templates_syntax(liquid_templates)
    LIQUID_TEMPLATE_KEYS.each do |key|
      next unless liquid_templates.key?(key)

      template = liquid_templates[key]
      next if template.nil? || template.empty?

      validate_liquid_syntax(template, "workflow.liquid_templates.#{key}")
    end
  end

  def validate_connection_keys(connection)
    extra_keys = connection.keys - CONNECTION_KEYS
    extra_keys.each { |key| errors << "unexpected key in workflow.connection: #{key}" }
  end

  def validate_connection_values(connection)
    CONNECTION_KEYS.each do |key|
      next unless connection.key?(key)

      value = connection[key]
      next if value.nil?

      errors << "workflow.connection.#{key} must be a string" unless value.is_a?(String)
    end
  end

  def validate_liquid_syntax(template, field_path)
    require_relative '../services/liquid/processor'
    processor = Liquid::Processor.new(template, {})

    errors << "invalid Liquid syntax in #{field_path}: #{processor.validation_errors}" unless processor.valid?
  rescue StandardError => e
    errors << "failed to validate Liquid syntax in #{field_path}: #{e.message}"
  end
end
