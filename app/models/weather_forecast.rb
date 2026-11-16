class WeatherForecast
  attr_reader :current_temperature, :high_temperature, :low_temperature, :extended_forecast

  def initialize(current:, high:, low:, extended_forecast: [])
    @current_temperature = current
    @high_temperature = high
    @low_temperature = low
    @extended_forecast = extended_forecast
  end

  def to_h
    {
      current_temperature: current_temperature,
      high_temperature: high_temperature,
      low_temperature: low_temperature,
      extended_forecast: extended_forecast
    }
  end
end