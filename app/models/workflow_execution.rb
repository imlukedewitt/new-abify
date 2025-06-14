# frozen_string_literal: true

##
# WorkflowExecution model represents a specific run of a Workflow
class WorkflowExecution < ApplicationRecord
  include Executable

  belongs_to :workflow
  belongs_to :data_source
  has_many :rows, dependent: :destroy
  has_many :batches, dependent: :destroy

  validates :workflow, presence: true
  validates :data_source, presence: true
end
