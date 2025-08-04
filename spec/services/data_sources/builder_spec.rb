# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataSources::Builder, type: :service do
  describe '.call' do
    context 'with a CSV file' do
      let(:file) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/3_rows.csv'), 'text/csv') }

      it 'creates a new Csv data source' do
        data_source = described_class.call(source: file)
        expect(data_source).to be_a(DataSources::Csv)
        expect(data_source).to be_persisted
      end
    end

    context 'with a JSON file' do
      let(:file) do
        Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/3_rows.json'), 'application/json')
      end

      it 'creates a new Json data source' do
        data_source = described_class.call(source: file, type: 'json')
        expect(data_source).to be_a(DataSources::Json)
        expect(data_source).to be_persisted
      end
    end
  end
end
