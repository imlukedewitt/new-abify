# frozen_string_literal: true

# .
class DataSourcesController < ApplicationController
  def create
    data_source = DataSources::Builder.call(source: params[:source])
    render json: { data_source_id: data_source.id }, status: :created
  rescue DataSources::Builder::InvalidSourceError => e
    render json: { error: "Invalid data source: #{e.message}" }, status: :bad_request
  end

  def index
    data_sources = DataSource.find_each.to_a
    render json: { data_sources: data_sources }
  end
end
