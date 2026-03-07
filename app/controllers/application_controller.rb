# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Respondable

  allow_browser versions: :modern

  # TODO: learn more about what this means
  protect_from_forgery with: :null_session

  before_action :check_session_timeout
  before_action :update_last_seen_at

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_content
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def not_found(exception)
    respond_to do |format|
      format.html { render file: Rails.public_path.join('404.html'), status: :not_found, layout: false }
      format.json { render json: { errors: [exception.message] }, status: :not_found }
    end
  end

  def unprocessable_content(exception)
    respond_to do |format|
      format.html { render :edit, status: :unprocessable_content }
      format.json do
        render json: { error: exception.record.errors.full_messages.join(', ') }, status: :unprocessable_content
      end
    end
  end

  def bad_request(exception)
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :bad_request }
    end
  end

  def check_session_timeout
    return unless session[:user_id].present?
    return unless session[:last_seen_at].present?

    return unless session[:last_seen_at] < 30.minutes.ago

    reset_session
    redirect_to login_path, alert: 'Signed out after inactivity'
  end

  def update_last_seen_at
    return unless session[:user_id].present?

    # Only update if more than 10 minutes have passed since last update
    return unless session[:last_seen_at].nil? || session[:last_seen_at] < 10.minutes.ago

    session[:last_seen_at] = Time.current
  end
end
