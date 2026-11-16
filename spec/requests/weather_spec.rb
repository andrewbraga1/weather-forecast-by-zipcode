require 'rails_helper'

RSpec.describe "Weather Acceptance", type: :request do
  describe "GET /" do
    it "renders the search form" do
      get root_path
      
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weather Forecast")
      expect(response.body).to include("Zip code")
      expect(response.body).to include("<form")
    end
  end

  describe "GET /weather", :vcr do
    context "when a valid zip code is provided" do
      it "displays the forecast and the live data badge" do
        get weather_path(zip_code: "90210")

        expect(response).to have_http_status(:ok)
        
        expect(response.body).to include("Current Temperature")
        expect(response.body).to include("Live Data")
        expect(response.body).to include("Next 3 Days Forecast")
        expect(response.body).not_to include("Cached")
      end
    end

    context "when testing the cache behavior from the UI", :vcr do
      let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

      before do
        allow(Rails).to receive(:cache).and_return(memory_store)
        Rails.cache.clear
      end

      it "displays the cached badge on the second request" do
        # First request 
        get weather_path(zip_code: "90210")
        
        # Second request should be from cache - Network disabled to ensure reliability
        WebMock.disable_net_connect!(allow_localhost: true)
        
        get weather_path(zip_code: "90210")
        
        expect(response.body).to include("Cached")
        
        WebMock.allow_net_connect!
      end
    end

    context "when no zip code is provided" do
      it "displays an error message" do
        get weather_path(zip_code: "")

        expect(response).to have_http_status(:ok) # It still renders the page, but with an error state
        expect(response.body).to include("Zip code is required")
      end
    end

    context "when a full address is provided", :vcr do
      it "extracts the zip code, fetches the forecast and displays the forecast details" do
        get weather_path(zip_code: "10001 Main St, Los Angeles, CA 90210")

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Current Temperature")
        expect(response.body).to include("Live Data")
      end
    end
  end
end