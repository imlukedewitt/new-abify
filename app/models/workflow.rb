# frozen_string_literal: true

##
# Workflow model
# Contains a collection of Steps to be executed in sequence
class Workflow < ApplicationRecord
  HANDLE_FORMAT = /\A[a-z][a-z0-9_-]*\z/

  belongs_to :connection, optional: true
  has_many :steps, dependent: :destroy
  has_many :workflow_executions, dependent: :restrict_with_error

  validates :name, presence: true
  validates :handle, format: {
    with: HANDLE_FORMAT,
    message: 'must start with a letter and contain only lowercase letters, numbers, hyphens, and underscores'
  }, if: -> { handle.present? }
  validates :handle, uniqueness: true, allow_nil: true
  validate :validate_config

  accepts_nested_attributes_for :steps

  ##
  # Find a workflow by ID or handle
  # @param identifier [String, Integer] the ID or handle to search for
  # @return [Workflow, nil] the found workflow or nil
  def self.find_by_id_or_handle(identifier)
    return nil if identifier.blank?

    # If it looks like a numeric ID, try finding by ID first
    if identifier.to_s.match?(/\A\d+\z/)
      find_by(id: identifier)
    else
      find_by(handle: identifier)
    end
  end

  ##
  # Find a workflow by ID or handle, raising RecordNotFound if not found
  # @param identifier [String, Integer] the ID or handle to search for
  # @return [Workflow] the found workflow
  # @raise [ActiveRecord::RecordNotFound] if not found
  def self.find_by_id_or_handle!(identifier)
    find_by_id_or_handle(identifier) || raise(ActiveRecord::RecordNotFound,
                                              "Couldn't find Workflow with identifier=#{identifier}")
  end

  def resolved_auth_config
    @resolved_auth_config ||= if connection.present?
                                connection.credentials
                              elsif config.present?
                                config.dig('connection', 'auth') || {}
                              else
                                {}
                              end
  end

  def workflow_config
    return nil if config.nil?
    return config['workflow'] if config.key?('workflow')

    config
  end

  private

  def validate_config
    return if config.nil?

    unless config.is_a?(Hash)
      errors.add(:config, 'must be a hash')
      return
    end

    validator = WorkflowConfigValidator.new(workflow_config)
    return if validator.valid?

    validator.errors.each { |error| errors.add(:config, error) }
  end
end
