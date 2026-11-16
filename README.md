# 🌤️ Weather Forecast by Zip Code

[![Ruby](https://img.shields.io/badge/Ruby-3.0.3-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-7.1.6-CC0000.svg)](https://rubyonrails.org/)
[![Tests](https://img.shields.io/badge/RSpec-100%25_Passing-brightgreen.svg)]()
[![Determinism](https://img.shields.io/badge/VCR%20%26%20WebMock-Offline_Certified-blue.svg)]()
[![Zero--Config](https://img.shields.io/badge/Setup-Zero_API_Keys-success.svg)]()

A high-performance, resilient weather forecasting web service built with **Ruby on Rails**. This application takes a US Zip Code or address, queries geocoding and meteorological data, and displays real-time weather metrics (current, high, and low temperatures) backed by a multi-tier caching strategy.

---

## 📑 Table of Contents
1. [System Architecture & Design Patterns](#1-system-architecture--design-patterns)
2. [Resilience & Network Fault Tolerance](#2-resilience--network-fault-tolerance)
3. [Architectural Decision Records (ADRs)](#3-architectural-decision-records-adrs)
4. [Testing Strategy & Determinism](#4-testing-strategy--determinism)
5. [Getting Started & Local Execution](#5-getting-started--local-execution)
6. [Future Production Roadmap](#6-future-production-roadmap)

---

## 1. System Architecture & Design Patterns

The application is structured following **Domain-Driven Design (DDD)** and **Clean Architecture** principles, enforcing separation of concerns between presentation, orchestration, domain entities, and external infrastructure.

```
                             HTTP Request (GET /weather?zip_code=90210)
                                                 │
                                                 ▼
                                     ┌───────────────────────┐
                                     │   WeatherController   │ (Skinny, RESTful Presentation)
                                     └───────────┬───────────┘
                                                 │
                                                 ▼
                                    ┌────────────────────────┐
                                    │ Weather::              │
                                    │ ForecastService        │ (Domain Orchestration)
                                    └────────────┬───────────┘
                                                 │
                    ┌────────────────────────────┴───────────────────────────┐
                    │                                                        │
          [ Cache Lookup ]                                          [ Cache Miss / Bypass ]
                    │                                                        │
                    ▼                                                        ▼
         ┌─────────────────────┐                                ┌─────────────────────────┐
         │ Rails.cache (Read)  │                                │ Geocoding::             │
         │ TTL: 30 minutes     │                                │ V1::OpenMeteoClient     │
         └─────────────────────┘                                └────────────┬────────────┘
                                                                             │ [ Lat / Lng ]
                                                                             ▼
                                                                ┌─────────────────────────┐
                                                                │ Weather::               │
                                                                │ V1::OpenMeteoClient     │
                                                                └────────────┬────────────┘
                                                                             │ Raw JSON Payload
                                                                             ▼
                                                                ┌─────────────────────────┐
                                                                │ Weather::V1::           │
                                                                │ OpenMeteoParser (ACL)   │
                                                                └────────────┬────────────┘
                                                                             │
                                                                             ▼
                                                                ┌─────────────────────────┐
                                                                │ WeatherForecast         │
                                                                │ (Pure Ruby Domain POPO) │
                                                                └─────────────────────────┘
```

### Architectural Responsibilities:

* **Presentation Layer (`WeatherController`):** Enforces thin controller conventions. It validates input existence, normalizes parameters, and delegates domain orchestration to the service object without leaking HTTP request handling into business rules.
* **Orchestration Layer (`Weather::ForecastService`):** Orchestrates cache evaluation, geocoding coordinates extraction, meteorological data retrieval, and cache persistence. Implements **Dependency Injection** via constructor parameters, enabling seamless mocking and provider swapping.
* **Anti-Corruption Layer (`Weather::V1::OpenMeteoParser`):** Protects internal domain models from vendor schema leaks. Translates external Open-Meteo JSON structures into an immutable, pure Ruby domain entity (`WeatherForecast`).
* **Infrastructure Layer (`Faraday` HTTP Clients):** Modular HTTP clients isolated under `Geocoding::V1` and `Weather::V1` namespaces, encapsulating network connectivity, timeouts, and headers.

---

## 2. Resilience & Network Fault Tolerance

External network interactions are inherently unstable. The service implements defensive engineering practices to guarantee uptime, system stability, and low latency:

| Mechanism | Configuration | Engineering Objective |
| :--- | :--- | :--- |
| **Fail-Fast Open Timeout** | `faraday.options.open_timeout = 2` | Aborts stalled TCP handshakes in 2s, protecting Puma worker threads from starvation. |
| **Strict Read Timeout** | `faraday.options.timeout = 5` | Caps network read time to 5s, preventing slow upstream responses from cascading into request bottlenecks. |
| **Cache-as-a-Shield** | `CACHE_TTL = 30.minutes` | Binds identical zip queries to a 30-minute memory cache, reducing downstream API consumption to $\le 2 \text{ requests/hour}$ per zip code. |
| **Graceful Error Handling** | `rescue Weather::ConnectionError` | Catches transport-level failures and maps them to descriptive user-facing domain errors without raising unhandled 500 exceptions. |
| **Memory Isolation** | `ActiveSupport::Cache::MemoryStore` | Zero-dependency local caching out of the box, with built-in cache key segmentation (`weather_forecast_{zip_code}`). |

---

## 3. Architectural Decision Records (ADRs)

### ADR 1: Open-Meteo Suite vs. Geocoder Gem (Nominatim) & Commercial APIs
* **Context:** The challenge requires converting an address/zip code into a forecast. Common alternatives include the `geocoder` gem (defaulting to OpenStreetMap/Nominatim) and commercial APIs (OpenWeatherMap, WeatherAPI).
* **Decision:** Selected **Open-Meteo** for both Geocoding and Weather data retrieval.
* **Rationale:**
  * OpenStreetMap's Nominatim enforces a strict 1 req/sec policy, requires identifying HTTP headers, and frequently blocks automated CI runners.
  * Commercial weather APIs require private API keys, credential provisioning, and secret management, creating setup friction for reviewers.
  * Open-Meteo provides high-performance, open-access endpoints requiring **zero API keys** and zero onboarding friction, while delivering deterministic responses and high availability.

### ADR 2: Custom Faraday Clients vs. Monolithic SDKs
* **Context:** Third-party wrapper gems add opaque abstractions and bulky transitive dependencies.
* **Decision:** Implemented custom HTTP clients using **Faraday 2.x**.
* **Rationale:**
  * Fine-grained control over connection timeout budgets (`open_timeout: 2s`, `timeout: 5s`).
  * Middleware extensibility (transparent JSON parsing via `faraday.response :json`, automatic status checking via `faraday.response :raise_error`).
  * Clear separation between HTTP transport and data normalization.

### ADR 3: Rails 7.1 Cookie Serialization & JSON Gem Compatibility Mitigation
* **Context:** In `json` gem version `3.0.0+`, the deprecated `quirks_mode` parameter was removed from `JSON.generate`. In Rails 7.1.6, `ActiveSupport::JSON::Encoding` internally passes `quirks_mode: true` during session and cookie serialization (`commit_session`), triggering an `ArgumentError: unknown keyword: quirks_mode` on all HTTP transactions.
* **Decision:** Explicitly pinned `gem "json", "< 3.0"` in the `Gemfile`, locking resolution to `json 2.21.2`.
* **Rationale:** Completely resolves runtime cookie serialization crashes without requiring unstable edge Rails upgrades or monkey-patching ActiveSupport internals.

---

## 4. Testing Strategy & Determinism

Testing follows **Acceptance Test-Driven Development (ATDD)** principles. The test suite is split into **Acceptance (Request)** specs and **Unit/Service** specs, achieving **100% test pass rates in offline mode**.

```
                   ┌────────────────────────────────────────┐
                   │        Acceptance Specs (E2E)          │
                   │        spec/requests/weather_spec.rb   │
                   └───────────────────┬────────────────────┘
                                       │
                                       ▼
                   ┌────────────────────────────────────────┐
                   │        Unit & Integration Specs        │
                   │  spec/services/weather/forecast_spec.rb│
                   └───────────────────┬────────────────────┘
                                       │
                                       ▼
                   ┌────────────────────────────────────────┐
                   │       VCR & WebMock Network Shield     │
                   │  (Guarantees 0 external calls in CI)   │
                   └────────────────────────────────────────┘
```

### Deterministic Offline Verification:
* **VCR & WebMock:** All external HTTP interactions are recorded into deterministic cassettes under `spec/vcr_cassettes/`. Tests execute in milliseconds without live network access.
* **Mathematical Cache Verification:** In `spec/requests/weather_spec.rb`, after the initial request records external data, `WebMock.disable_net_connect!` is invoked before the second query. The test passes **only if the response is served purely from cache**, proving cache behavior deterministically.

### Running the Test Suite:
```bash
bundle exec rspec
```

**Expected Execution Output:**
```text
.......

Finished in 0.42 seconds (files took 1.45 seconds to load)
7 examples, 0 failures
```

---

## 5. Getting Started & Local Execution

### Prerequisites
* **Ruby:** `3.0.3` (managed via `rbenv`, `rvm`, or `asdf`)
* **Rails:** `7.1.6`
* **Bundler:** `>= 2.2`
* **SQLite3**

### Local Setup (Zero-Friction, Zero-Credentials)

```bash
# 1. Clone repository
git clone https://github.com/AndrewBraga/weather-forecast-by-zipcode.git
cd weather-forecast-by-zipcode

# 2. Install dependencies
bundle install

# 3. Setup local database
bin/rails db:prepare

# 4. Boot the Rails server
bin/rails server
```

Open your browser and navigate to:
```
http://localhost:3000
```

* **Live Data Query:** Search for any valid US Zip Code (e.g., `90210`). The view renders real-time data accompanied by the `📡 Live Data` badge.
* **Cache Validation:** Repeat the search with the same zip code within 30 minutes. The view renders instantly accompanied by the `⚡ Cached Data` badge.

---

## 6. Future Production Roadmap

In a distributed, mission-critical production environment, the following extensions are planned:

1. **Distributed Caching Layer:** Transition from local `MemoryStore` to an HA **Redis Sentinel** cluster (`kredis` / `redis-cache-store`), utilizing cache namespace isolation.
2. **Circuit Breaker & Fallback Provider:** Integrate `stoplight` or `circuitbox` around the `ForecastService` to dynamically trip into a secondary provider (e.g., WeatherAPI) upon elevated error rates.
3. **Stale-While-Revalidate (SWR):** Implement dual-TTL caching (`fresh_until = 30.minutes`, `stale_until = 24.hours`) to serve stale forecasts with a `⚠️ Stale Cache (API Offline)` badge during catastrophic upstream downtime.