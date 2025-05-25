# frozen_string_literal: true

##
# Workflow model
class Workflow < ApplicationRecord
  has_many :steps
end
