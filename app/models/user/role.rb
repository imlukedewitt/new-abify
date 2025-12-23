class User
  module Role
    extend ActiveSupport::Concern

    included do
      # def owner? def admin? def member?
      enum :role, %w[owner admin member].index_by(&:itself)
    end
  end
end
