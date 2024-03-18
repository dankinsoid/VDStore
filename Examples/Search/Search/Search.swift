import SwiftUI
import VDStore

private let readMe = """
This application demonstrates live-searching with the VDStore. As you type the \
events are debounced for 300ms, and when you stop typing an API request is made to load \
locations. Then tapping on a location will load weather.
"""

// MARK: - Search state

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

// MARK: - Search actions

@Actions
extension Store<Search> {

	func searchQueryChanged(query: String) {
		state.searchQuery = query
		cancel(Self.searchQueryChangeDebounced)
		guard query.isEmpty else { return }
		state.results = []
		state.weather = nil
	}

	@CancelInFlight
	func searchQueryChangeDebounced() async {
		try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 3)
		guard !state.searchQuery.isEmpty, !Task.isCancelled else {
			return
		}
		do {
			let response = try await di.weatherClient.search(state.searchQuery)
			try Task.checkCancellation()
			state.results = response.results
		} catch {
			guard !Task.isCancelled, !(error is CancellationError) else { return }
			state.results = []
		}
	}
}

@Actions
extension Store<Search> {

	@CancelInFlight
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
								Task {
									await $state.searchResultTapped(location: location)
								}
							} label: {
								HStack {
									Text(location.name)

									if state.resultForecastRequestInFlight?.id == location.id {
										ProgressView()
									}
								}
							}

							if location.id == state.weather?.id {
								weatherView(locationWeather: state.weather)
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
			await $state.searchQueryChangeDebounced()
		}
	}

	@ViewBuilder
	func weatherView(locationWeather: Search.Weather?) -> some View {
		if let locationWeather {
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
