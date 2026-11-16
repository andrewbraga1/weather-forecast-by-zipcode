# spec/services/weather/forecast_service_spec.rb
require 'rails_helper'

RSpec.describe Weather::ForecastService do
  describe '#call', :vcr do
    let(:zip_code) { "90210" }
    subject(:service) { described_class.new(zip_code) }

    context 'when requesting for the first time (no cache)' do
      before do
        Rails.cache.clear
      end

      it 'returns success and data from the external API' do
        result = service.call

        expect(result[:success]).to be true
        expect(result[:from_cache]).to be false
        expect(result[:data]).to have_key(:current_temperature)
        expect(result[:data]).to have_key(:high_temperature)
        expect(result[:data]).to have_key(:low_temperature)
        expect(result[:data][:extended_forecast]).to be_an(Array)
        expect(result[:data][:extended_forecast].size).to eq(3)
        expect(result[:data][:extended_forecast].first).to include(:date, :high_temperature, :low_temperature)
      end
    end

    context 'when requesting the same zip code within 30 minutes' do
      let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

      before do
        allow(Rails).to receive(:cache).and_return(memory_store)
        Rails.cache.clear
        
        service.call
      end

      it 'returns the data from the cache without hitting the API' do
        WebMock.disable_net_connect!(allow_localhost: true)

        result = described_class.new(zip_code).call

        expect(result[:success]).to be true
        expect(result[:from_cache]).to be true
        expect(result[:data][:current_temperature]).to be_a(Numeric)

        WebMock.allow_net_connect!
      end
    end

    context 'when zip code is missing' do
      subject(:service) { described_class.new("") }

      it 'returns an error instantly without network call' do
        result = service.call

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Zip code is required")
      end
    end
  end
end