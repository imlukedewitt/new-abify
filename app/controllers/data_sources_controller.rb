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
    @pagy, @data_sources = pagy(:offset, DataSource.order(id: :desc))
    respond_to do |format|
      format.json { render json: { data_sources: @data_sources } }
      format.html { render :index  }
    end
  end

  def show
    @data_source = DataSource.find(params[:id])
    @pagy, @rows = pagy(:offset, @data_source.rows.order(id: :asc))

    respond_to do |format|
      format.json { render json: { data_source: @data_source } }
      format.html do
        @workflows = Workflow.all
        render :show
      end
    end
  end

  def update
    @data_source = DataSource.find(params[:id])
    source = params[:source]

    row_ids = @data_source.row_ids
    StepExecution.where(row_id: row_ids).delete_all
    RowExecution.where(row_id: row_ids).delete_all
    Row.where(id: row_ids).delete_all
    @data_source.name = File.basename(source.original_filename) if source.respond_to?(:original_filename)
    @data_source.save!

    # Reload to clear stale association cache, then load new rows
    @data_source.reload
    @data_source.source = source
    @data_source.load_data

    redirect_to data_source_path(@data_source), notice: 'Data source updated successfully.'
  rescue StandardError => e
    redirect_to data_source_path(@data_source), alert: "Failed to update: #{e.message}"
  end

  def destroy
    @data_source = DataSource.find(params[:id])
    @data_source.destroy!
    redirect_to data_sources_path, notice: 'Data source deleted.'
  rescue StandardError => e
    redirect_to data_source_path(@data_source), alert: "Failed to delete: #{e.message}"
  end
end
