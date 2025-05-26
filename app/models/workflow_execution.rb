# frozen_string_literal: true

##
# WorkflowExecution model represents a specific run of a Workflow
# Also known as "An Import" or "A Run"
class WorkflowExecution < ApplicationRecord
  belongs_to :workflow
  belongs_to :data_source
  has_many :rows, dependent: :destroy
  has_many :batches, through: :rows

  validates :workflow, presence: true
  validates :data_source, presence: true
end
