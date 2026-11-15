Weather Forecast by ZipCode

1) Requirements

As requested in the take-home assessment, this project must fulfill the following:

* Must be built in Ruby on Rails.
* Accept an address as input.
* Retrieve forecast data for the given zip code (including current temperature).
* Display the requested forecast details to the user.
* Cache the forecast details for 30 minutes for all subsequent requests by zip codes.
* Display an indicator if the result is pulled from the cache.
* **Bonus:** Retrieve high/low and/or extended forecast.

2) Assumptions

* Functionality is a priority over form.
* The project is open to interpretation


3) Initial Insights & Architectural Planning

Before writing any code, I mapped out the following technical approach to address the requirements efficiently. Since, it is essencially an API consumption, I decided as follow:

A) Minimalist Framework Setup

Since the application's core responsibility is consuming a 3rd-party API and caching the HTTP transaction, a full-blown Rails monolith is overkill. 
I will bootstrap the application using Rails minimal resources/tooling as possible for this scenario. Skipping modules like ActionMailer, ActionCable, and ActiveStorage will keep the boot time fast, the bundle size small, and ensure zero friction for the reviewers when running the project locally.

B) Privacy & Data Minimization

The user inputs a full address, but the API only needs a zip code. 
In order to achieve data privacy best practices, I will not store or pass the full address string to the external Weather API. I'll use a geocoding step to extract only the zip code. This ensures sensitive location data is minimized early in the flow.

C) Cache as a Shield

The requirement demands a 30-minute cache by zip code.
From my POV, this cache won't just be a UX improvement. It will act as an architectural shield for our application by caching at the service level. Also, It protects the application against external API rate limits and drastically reduce latency for recurring zip code searches.

D) Testing Strategy

Instead of relying on live external APIs for test suites leads to flaky tests and rate-limit exhaustion. I will configure RSpec with VCR to record and mock the HTTP interactions deterministically from the very beginning.

4) Tools and resources

A) Gem geocoder

Object geocoding (by street or IP address), reverse geocoding (coordinates to street address), distance queries for ActiveRecord and Mongoid, result caching, and more. Designed for Rails but works with Sinatra and other Rack frameworks too.
reference: https://rubygems.org/gems/geocoder

B) Weather API options

WeatherAPI, OpenWeatherMap
reference: https://medium.com/@ajeet214/9-free-weather-apis-for-ai-data-projects-6bfc66022e46
