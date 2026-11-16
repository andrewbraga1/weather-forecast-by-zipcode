class WeatherController < ApplicationController
  def index
    if params.has_key?(:zip_code)
      service = Weather::ForecastService.new(params[:zip_code])
      @result = service.call
    end
  end
end