# https://open-meteo.com/en/docs has all details such as Parameter,Format, Required, Default,Description
module Weather
  class V1::OpenMeteoClient
    def initialize(base_url: ENV.fetch('OPEN_METEO_V1_BASE_URL', 'https://api.open-meteo.com/v1'))
      @base_url = base_url
      @connection = setup_connection
    end

    def fetch_forecast(latitude:, longitude:)
      response = @connection.get('forecast') do |req|
        req.params['latitude'] = latitude
        req.params['longitude'] = longitude
        
        req.params['current'] = 'temperature_2m' 
        req.params['daily'] = 'temperature_2m_max,temperature_2m_min' # min/max temperature
        req.params['timezone'] = 'auto'
      end

      Weather::V1::OpenMeteoParser.parse(response.body)
    rescue Faraday::Error => e
      Rails.logger.error("OpenMeteo API V1 Error: #{e.message}")
      raise Weather::ConnectionError, "Failed to connect to OpenMeteo API"
    end

    private

    def setup_connection
      Faraday.new(url: @base_url) do |faraday|
        faraday.request :json
        faraday.response :json 
        faraday.response :raise_error 
        
        # Timeout configuration for fault tolerance
        faraday.options.timeout = 5
        faraday.options.open_timeout = 2
        
        faraday.adapter Faraday.default_adapter
      end
    end
  end
end