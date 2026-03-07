module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate
    before_action :require_current_user
  end

  private

  def authenticate
    # Check session-based authentication first
    Current.user ||= User.find_by(id: session[:user_id]) if session[:user_id].present?

    # If session auth didn't set Current.user, fall back to token auth
    return unless Current.user.nil? && request.authorization.present?

    authenticate_or_request_with_http_token do |token|
      Current.user = User.find_by(api_token: token)
    end
  end

  def require_current_user
    return if Current.user.present?

    respond_to do |format|
      format.html { redirect_to login_path, alert: 'Please sign in' }
      format.json { render_unauthorized }
    end
  end

  def require_admin
    render_unauthorized unless Current.user&.admin?
  end

  def render_unauthorized
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
