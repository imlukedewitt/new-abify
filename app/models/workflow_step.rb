class WorkflowStep < ApplicationRecord
  belongs_to :workflow
  default_scope { order(order: :asc) }

  validates :config, presence: true
  validates :name, presence: true
  validates :order, presence: true, numericality: { only_integer: true , greater_than: 0 }
end
