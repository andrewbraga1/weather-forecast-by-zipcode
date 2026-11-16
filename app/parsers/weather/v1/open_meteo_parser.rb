module Weather
  class V1::OpenMeteoParser
    def self.parse(response_body)
      times = response_body.dig('daily', 'time') || []
      highs = response_body.dig('daily', 'temperature_2m_max') || []
      lows  = response_body.dig('daily', 'temperature_2m_min') || []

      extended = (1..3).map do |i|
        next unless times[i]

        {
          date: times[i],
          high_temperature: highs[i],
          low_temperature: lows[i]
        }
      end.compact

      WeatherForecast.new(
        current: response_body.dig('current', 'temperature_2m'),
        high: highs[0],
        low: lows[0],
        extended_forecast: extended
      )
    end
  end
end