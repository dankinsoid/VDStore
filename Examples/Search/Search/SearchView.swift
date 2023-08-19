import VDStore
import SwiftUI

private let readMe = """
  This application demonstrates live-searching with the VDStore. As you type the \
  events are debounced for 300ms, and when you stop typing an API request is made to load \
  locations. Then tapping on a location will load weather.
  """

// MARK: - Search feature domain

struct Search: Equatable {
    
    var results: [GeocodingSearch.Result] = []
    var resultForecastRequestInFlight: GeocodingSearch.Result?
    var searchQuery = ""
    var weather: Weather?
    
    struct Weather: Equatable {
        var id: GeocodingSearch.Result.ID
        var days: [Day]
        
        struct Day: Equatable {
            var date: Date
            var temperatureMax: Double
            var temperatureMaxUnit: String
            var temperatureMin: Double
            var temperatureMinUnit: String
        }
    }
}

extension Store<Search> {
  
    func forecastResponse(id: GeocodingSearch.Result.ID, result: Result<Forecast, Error>) {
        var state = self.state
        defer { self.state = state }

        switch result {
        case .failure:
            state.weather = nil
            state.resultForecastRequestInFlight = nil
        case let .success(forecast):
            state.weather = State.Weather(
                id: id,
                days: forecast.daily.time.indices.map {
                    State.Weather.Day(
                        date: forecast.daily.time[$0],
                        temperatureMax: forecast.daily.temperatureMax[$0],
                        temperatureMaxUnit: forecast.dailyUnits.temperatureMax,
                        temperatureMin: forecast.daily.temperatureMin[$0],
                        temperatureMinUnit: forecast.dailyUnits.temperatureMin
                    )
                }
            )
            state.resultForecastRequestInFlight = nil
        }
    }
    
    func searchQueryChanged(query: String) {
        var state = self.state
        defer { self.state = state }
        state.searchQuery = query
        if query.isEmpty {
            state.results = []
            state.weather = nil
            dependencies.tasksStorage.cancel(id: CancelID.location)
        }
    }
    
    func searchQueryChangeDebounced() -> Task<Void, Never> {
        guard !state.searchQuery.isEmpty else {
            return Task {}
        }
        return Task { [query = state.searchQuery] in
            do {
                try await searchResponse(result: .success(dependencies.weatherClient.search(query)))
            } catch {
                searchResponse(result: .failure(error))
            }
        }
        .store(in: dependencies.tasksStorage, id: CancelID.location)
    }
    
    func searchResponse(result: Result<GeocodingSearch, Error>) {
        switch result {
        case .failure:
            state.results = []
        case let .success(response):
            state.results = response.results
        }
    }
        
    func searchResultTapped(location: GeocodingSearch.Result) {
        state.resultForecastRequestInFlight = location
        
        Task {
            do {
                try await forecastResponse(id: location.id, result: .success(dependencies.weatherClient.forecast(location)))
            } catch {
                forecastResponse(id: location.id, result: .failure(error))
            }
        }
        .store(in: dependencies.tasksStorage, id: CancelID.weather)
    }
    
    private enum CancelID { case location, weather }
}

// MARK: - Search feature view

struct SearchView: View {
    
  @ViewStore var state = Search()

  var body: some View {
      NavigationStack {
        VStack(alignment: .leading) {
          Text(readMe)
            .padding()

          HStack {
            Image(systemName: "magnifyingglass")
            TextField(
              "New York, San Francisco, ...",
              text: Binding {
                  state.searchQuery
              } set: { text in
                  $state.searchQueryChanged(query: text)
              }
            )
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
            .disableAutocorrection(true)
          }
          .padding(.horizontal, 16)

          List {
            ForEach(state.results) { location in
              VStack(alignment: .leading) {
                Button {
                  $state.searchResultTapped(location: location)
                } label: {
                  HStack {
                    Text(location.name)

                    if state.resultForecastRequestInFlight?.id == location.id {
                      ProgressView()
                    }
                  }
                }

                if location.id == state.weather?.id {
                    self.weatherView(locationWeather: state.weather)
                }
              }
            }
          }

          Button("Weather API provided by Open-Meteo") {
            UIApplication.shared.open(URL(string: "https://open-meteo.com/en")!)
          }
          .foregroundColor(.gray)
          .padding(.all, 16)
        }
        .navigationTitle("Search")
      }
      .task(id: state.searchQuery) {
        do {
          try await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
            await $state.searchQueryChangeDebounced().value
        } catch {}
      }
  }

  @ViewBuilder
  func weatherView(locationWeather: Search.Weather?) -> some View {
    if let locationWeather = locationWeather {
      let days = locationWeather.days
        .enumerated()
        .map { idx, weather in formattedWeather(day: weather, isToday: idx == 0) }

      VStack(alignment: .leading) {
        ForEach(days, id: \.self) { day in
          Text(day)
        }
      }
      .padding(.leading, 16)
    }
  }
}

// MARK: - Private helpers

private func formattedWeather(day: Search.Weather.Day, isToday: Bool) -> String {
  let date =
    isToday
    ? "Today"
    : dateFormatter.string(from: day.date).capitalized
  let min = "\(day.temperatureMin)\(day.temperatureMinUnit)"
  let max = "\(day.temperatureMax)\(day.temperatureMaxUnit)"

  return "\(date), \(min) – \(max)"
}

private let dateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "EEEE"
  return formatter
}()

// MARK: - SwiftUI previews

struct SearchView_Previews: PreviewProvider {
  static var previews: some View {
    SearchView()
  }
}
