# frozen_string_literal: true

##
# Connection model
# Stores encrypted API credentials that can be referenced by workflows
class Connection < ApplicationRecord
  belongs_to :user
  has_many :workflows, dependent: :nullify

  attribute :credentials, :json
  encrypts :credentials

  validates :name, presence: true
  validates :handle, presence: true
  validates :credentials, presence: true

  validates :handle, format: {
    with: /\A[a-z][a-z0-9_]*\z/,
    message: 'must start with a letter and contain only lowercase letters, numbers, and underscores'
  }, if: -> { handle.present? }

  validates :handle, uniqueness: { scope: :user_id }

  validate :credentials_must_be_hash

  def base_url
    return nil if subdomain.blank? || domain.blank?

    "https://#{subdomain}.#{domain}"
  end

  private

  def credentials_must_be_hash
    return if credentials.nil?

    errors.add(:credentials, 'must be a hash') unless credentials.is_a?(Hash)
  end
end
