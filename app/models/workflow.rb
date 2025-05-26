# frozen_string_literal: true

##
# Workflow model
# Contains a collection of Steps to be executed in sequence
class Workflow < ApplicationRecord
  has_many :steps, dependent: :destroy
  has_many :workflow_executions, dependent: :restrict_with_error

  validates :name, presence: true

  # Helper for creating a workflow execution
  def create_execution(data_source)
    workflow_executions.create(data_source: data_source)
  end
end
