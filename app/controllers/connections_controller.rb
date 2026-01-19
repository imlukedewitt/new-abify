# frozen_string_literal: true

## ConnectionsController
class ConnectionsController < ApplicationController
  include Respondable

  before_action :set_connection, only: %i[show edit update destroy]

  def index
    @connections = Connection.all
    @connections = @connections.where(user_id: params[:user_id]) if params[:user_id]

    respond_to do |format|
      format.html
      format.json { render json: { connections: @connections.map { |c| serialize_connection(c) } } }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: { connection: serialize_connection(@connection) } }
    end
  end

  def new
    @connection = Connection.new
  end

  def edit; end

  def create
    @connection = Connection.new(connection_params)

    return respond_with_errors(@connection, :new) unless @connection.save

    respond_to do |format|
      format.html { redirect_to connection_path(@connection), notice: 'Connection created successfully' }
      format.json { render json: { connection_id: @connection.id }, status: :created }
    end
  end

  def update
    return respond_with_errors(@connection, :edit) unless @connection.update(connection_params)

    respond_to do |format|
      format.html { redirect_to connection_path(@connection), notice: 'Connection updated successfully' }
      format.json { render json: { connection: serialize_connection(@connection) } }
    end
  end

  def destroy
    @connection.destroy

    respond_to do |format|
      format.html { redirect_to connections_path, notice: 'Connection deleted successfully' }
      format.json { head :no_content }
    end
  end

  private

  def set_connection
    @connection = Connection.find(params[:id])
  end

  def connection_params
    permitted = params.require(:connection).permit(:user_id, :name, :handle, :subdomain, :domain, credentials: {})
    # this is just temporary while the UI form is basic
    raw_creds = params[:connection][:credentials]
    permitted[:credentials] = JSON.parse(raw_creds) if raw_creds.is_a?(String) && raw_creds.present?
    permitted
  rescue JSON::ParserError
    permitted
  end

  def serialize_connection(connection)
    connection.as_json(except: :credentials, methods: :base_url)
  end
end
