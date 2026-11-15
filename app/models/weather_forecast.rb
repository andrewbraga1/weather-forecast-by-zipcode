class WeatherForecast
  attr_reader :current_temperature, :high_temperature, :low_temperature

  def initialize(current:, high:, low:)
    @current_temperature = current
    @high_temperature = high
    @low_temperature = low
  end

  def to_h
    {
      current_temperature: current_temperature,
      high_temperature: high_temperature,
      low_temperature: low_temperature
    }
  end
end