module Weather
  class ForecastService
    CACHE_TTL = 30.minutes

    def initialize(zip_code_or_address, weather_client: Weather::V1::OpenMeteoClient.new, geocoding_client: Geocoding::V1::OpenMeteoClient.new)
      @input = zip_code_or_address.to_s.strip
      @zip_code = extract_zip_code(@input)
      @weather_client = weather_client
      @geocoding_client = geocoding_client
    end

    def call
      return error_result("Zip code is required") if @zip_code.blank?
      cached_forecast = Rails.cache.read(cache_key)
      return success_result(cached_forecast, from_cache: true) if cached_forecast

      coordinates = @geocoding_client.fetch_coordinates(@zip_code)
      return error_result("Could not find location for the provided zip code") unless coordinates

      fetch_and_cache_forecast(coordinates)
    rescue Weather::ConnectionError => e
      error_result("Weather service is temporarily unavailable. Please try again later.")
    end

    private
    def extract_zip_code(input)
      input.scan(/\b\d{5}\b/).last || input
    end

    def cache_key
      "weather_forecast_#{@zip_code}"
    end

    def fetch_and_cache_forecast(coordinates)
      forecast_domain_object = @weather_client.fetch_forecast(
        latitude: coordinates[0], 
        longitude: coordinates[1]
      )

      forecast_data = forecast_domain_object.to_h
      # create a cache entry with a TTL of 30 minutes as requested
      Rails.cache.write(cache_key, forecast_data, expires_in: CACHE_TTL)

      success_result(forecast_data, from_cache: false)
    end

    def success_result(data, from_cache:)
      {
        success: true,
        data: data,
        from_cache: from_cache,
        error: nil
      }
    end

    def error_result(message)
      {
        success: false,
        data: nil,
        from_cache: false,
        error: message
      }
    end
  end
end