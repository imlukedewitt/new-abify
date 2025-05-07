# frozen_string_literal: true

##
# Represents a step in a workflow sequence.
# Each step has a specific order, configuration, and name.
#
# @attr_reader [String] name The name of the workflow step
# @attr_reader [Hash] config The configuration settings for this step
# @attr_reader [Integer] order The position of this step in the workflow sequence
#
# @attr [Workflow] workflow The workflow this step belongs to
class WorkflowStep < ApplicationRecord
  belongs_to :workflow
  default_scope { order(order: :asc) }

  validates :config, presence: true
  validates :name, presence: true
  validates :order, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
