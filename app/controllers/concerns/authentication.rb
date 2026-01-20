module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
    before_action :require_current_user
  end

  private

  def authenticate
    # TODO: Remove this bypass once session auth is implemented
    if Rails.env.development? && !request.authorization.present?
      Current.user ||= User.last
      return
    end

    authenticate_or_request_with_http_token do |token|
      Current.user = User.find_by(api_token: token)
    end
  end

  def require_current_user
    render_unauthorized unless Current.user.present?
  end

  def require_admin
    render_unauthorized unless Current.user.admin?
  end

  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
