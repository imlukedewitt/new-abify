# frozen_string_literal: true

## ConnectionsController
class ConnectionsController < ApplicationController
  def create
    connection = Connection.new(connection_params)

    if connection.save
      render json: { connection_id: connection.id }, status: :created
    else
      render json: { error: connection.errors.full_messages.join(', ') }, status: :unprocessable_content
    end
  end

  def index
    connections = Connection.all
    connections = connections.where(user_id: params[:user_id]) if params[:user_id]
    render json: { connections: connections.map { |c| serialize_connection(c) } }
  end

  def show
    connection = Connection.find(params[:id])
    render json: { connection: serialize_connection(connection) }
  rescue ActiveRecord::RecordNotFound => e
    render json: { errors: e }, status: :bad_request
  end

  def update
    connection = Connection.find(params[:id])

    if connection.update(connection_params)
      render json: { connection: serialize_connection(connection) }
    else
      render json: { error: connection.errors.full_messages.join(', ') }, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotFound => e
    render json: { errors: e }, status: :bad_request
  end

  def destroy
    connection = Connection.find(params[:id])
    connection.destroy
    head :no_content
  rescue ActiveRecord::RecordNotFound => e
    render json: { errors: e }, status: :bad_request
  end

  private

  def connection_params
    params.permit(:user_id, :name, :handle, :subdomain, :domain, credentials: {})
  end

  def serialize_connection(connection)
    connection.as_json(except: :credentials, methods: :base_url)
  end
end
