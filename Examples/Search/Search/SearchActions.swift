import Foundation
import VDStore

@Actions
extension Store<Search> {

	func searchQueryChanged(query: String) {
		state.searchQuery = query
		cancel(Self.searchQueryChangeDebounced)
		guard query.isEmpty else { return }
		state.results = []
		state.weather = nil
	}

	func searchQueryChangeDebounced() async {
		try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
		guard !state.searchQuery.isEmpty, !Task.isCancelled else {
			return
		}
		do {
			let response = try await di.weatherClient.search(state.searchQuery)
			guard !Task.isCancelled else { return }
			state.results = response.results
		} catch {
			guard !Task.isCancelled, !(error is CancellationError) else { return }
			state.results = []
		}
	}
}

@Actions
extension Store<Search> {

	func searchResultTapped(location: GeocodingSearch.Result) async {
		state.resultForecastRequestInFlight = location
		defer { state.resultForecastRequestInFlight = nil }
		do {
			let forecast = try await di.weatherClient.forecast(location)
			state.weather = State.Weather(
				id: location.id,
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
		} catch {
			state.weather = nil
		}
	}
}
