# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Respondable

  allow_browser versions: :modern

  # TODO: look into what this is and potentially remove it
  # For example Fizzy uses a custom class instead RequestForgeryProtection
  protect_from_forgery with: :null_session

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def not_found(exception)
    respond_to do |format|
      format.html { render file: Rails.public_path.join('404.html'), status: :not_found, layout: false }
      format.json { render json: { errors: [exception.message] }, status: :not_found }
    end
  end

  def unprocessable_entity(exception)
    respond_to do |format|
      format.html { render :edit, status: :unprocessable_entity }
      format.json do
        render json: { error: exception.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    end
  end

  def bad_request(exception)
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :bad_request }
    end
  end
end
