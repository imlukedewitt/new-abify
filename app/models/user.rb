class User < ApplicationRecord
  has_many :connections, dependent: :destroy
end
