module Geocoding
  class V1::OpenMeteoClient
    def initialize(base_url: ENV.fetch('GEOCODING_OPEN_METEO_V1_BASE_URL', 'https://geocoding-api.open-meteo.com/v1'))
      @base_url = base_url
      @connection = setup_connection
    end

    def fetch_coordinates(zip_code)
      response = @connection.get('search') do |req|
        req.params['name'] = zip_code
        req.params['count'] = 1
      end
      # Response is an array if any
      location = response.body['results']&.first
      
      return nil unless location

      [location['latitude'], location['longitude']]
    rescue Faraday::Error => e
      Rails.logger.error("Geocoding API Error: #{e.message}")
      nil
    end

    private

    def setup_connection
      Faraday.new(url: @base_url) do |faraday|
        faraday.request :json
        faraday.response :json 
        faraday.response :raise_error 
        
        faraday.options.timeout = 5
        faraday.options.open_timeout = 2
        
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end