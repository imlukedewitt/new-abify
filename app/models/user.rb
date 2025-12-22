class User < ApplicationRecord
  after_initialize :set_api_token, if: :new_record?

  has_many :connections, dependent: :destroy

  validates :api_token, uniqueness: true

  attribute :api_token, :string
  encrypts :api_token, deterministic: true

  private

  def set_api_token
    self.api_token ||= SecureRandom.hex(20)
  end
end
