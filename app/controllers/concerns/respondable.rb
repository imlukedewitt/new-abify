# frozen_string_literal: true

module Respondable
  extend ActiveSupport::Concern

  private

  def respond_with_errors(record, html_action)
    respond_to do |format|
      format.html { render html_action, status: :unprocessable_content }
      format.json { render json: { errors: record.errors.full_messages }, status: :unprocessable_content }
    end
  end
end
