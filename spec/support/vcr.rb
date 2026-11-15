require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  # default folder 
  config.cassette_library_dir = 'spec/vcr_cassettes'
  
  # Intercept HTTP requests
  config.hook_into :webmock
  
  # Permite que você pule a configuração do VCR em testes que não fazem requisições HTTP
  config.configure_rspec_metadata!
  
  # Mask sensitive data in the recorded cassettes
  # config.filter_sensitive_data('<WEATHER_API_KEY>') { ENV['WEATHER_API_KEY'] }
end