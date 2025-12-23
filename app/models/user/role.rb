class User
  module Role
    extend ActiveSupport::Concern

    included do
      # def owner? def admin? def member?
      enum :role, %w[owner admin member system].index_by(&:itself)

      def admin?
        super || owner?
      end
    end
  end
end
