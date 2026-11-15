module Weather
  class V1::OpenMeteoParser
    def self.parse(response_body)
      WeatherForecast.new(
        current: response_body.dig('current', 'temperature_2m'),
        high: response_body.dig('daily', 'temperature_2m_max', 0),
        low: response_body.dig('daily', 'temperature_2m_min', 0)
      )
    end
  end
end