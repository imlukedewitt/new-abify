# frozen_string_literal: true

##
# Base controller for API endpoints
# Provides common functionality for all API controllers including CSRF protection handling
class ApiController < ApplicationController
  # Skip CSRF protection for API requests since we're typically using token-based authentication
  skip_before_action :verify_authenticity_token

  # Set response format to JSON by default
  before_action :set_default_format

  # Rescue from common exceptions and return proper JSON error responses
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def set_default_format
    request.format = :json
  end

  def not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { error: exception.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
  end

  def bad_request(exception)
    render json: { error: exception.message }, status: :bad_request
  end
end
