import Foundation
import VDStore

@Actions
extension Store<Search> {

    func searchQueryChanged(query: String) {
        state.searchQuery = query
        guard query.isEmpty else { return }
        state.results = []
        state.weather = nil
        cancel(Self.searchQueryChangeDebounced)
    }

    func searchQueryChangeDebounced() async {
        try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
        guard !state.searchQuery.isEmpty, !Task.isCancelled else {
            return
        }
        do {
            let response = try await dependencies.weatherClient.search(state.searchQuery)
            guard !Task.isCancelled else { return }
            searchResponse(result: .success(response))
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            searchResponse(result: .failure(error))
        }
    }
}

@Actions
extension Store<Search> {

    func searchResultTapped(location: GeocodingSearch.Result) async {
        state.resultForecastRequestInFlight = location
        do {
            try await forecastResponse(id: location.id, result: .success(dependencies.weatherClient.forecast(location)))
        } catch {
            forecastResponse(id: location.id, result: .failure(error))
        }
    }

    func searchResponse(result: Result<GeocodingSearch, Error>) {
        switch result {
        case .failure:
            state.results = []
        case let .success(response):
            state.results = response.results
        }
    }

    func forecastResponse(id: GeocodingSearch.Result.ID, result: Result<Forecast, Error>) {
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
}
