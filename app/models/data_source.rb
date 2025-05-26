# frozen_string_literal: true

##
# DataSource model represents a source of data for a workflow execution
# This could be a CSV file, JSON data, API response, etc.
class DataSource < ApplicationRecord
  has_many :rows
  has_many :workflow_executions

  validates :name, presence: true
  validates :type, presence: true
end
