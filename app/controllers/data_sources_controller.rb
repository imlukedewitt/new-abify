# frozen_string_literal: true

# .
class DataSourcesController < ApplicationController
  def new
    @data_source = DataSource.new
  end

  def create
    data_source = DataSources::Builder.call(source: params[:source])
    respond_to do |format|
      format.json { render json: { data_source_id: data_source.id }, status: :created }
      format.html { redirect_to data_source_path(data_source), notice: 'Data source created successfully.' }
    end
  rescue DataSources::Builder::InvalidSourceError => e
    respond_to do |format|
      format.json { render json: { error: "Invalid data source: #{e.message}" }, status: :bad_request }
      format.html { redirect_to new_data_source_path, alert: "Invalid data source: #{e.message}" }
    end
  end

  def index
    @data_sources = DataSource.all
    respond_to do |format|
      format.json { render json: { data_sources: @data_sources } }
      format.html { render :index  }
    end
  end

  def show
    @data_source = DataSource.find(params[:id])
    respond_to do |format|
      format.json { render json: { data_source: @data_source } }
      format.html do
        @workflows = Workflow.all
        render :show
      end
    end
  end
end
