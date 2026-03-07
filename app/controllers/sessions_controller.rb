# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :authenticate, only: %i[new create]
  skip_before_action :require_current_user, only: %i[new create]

  def new; end

  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      session[:last_seen_at] = Time.current
      redirect_to workflows_path, notice: 'Signed in successfully'
    else
      flash.now[:alert] = 'Invalid credentials, please try again'
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: 'Signed out successfully'
  end
end
