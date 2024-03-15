import SwiftUI
import VDStore

private let readMe = """
This application demonstrates live-searching with the VDStore. As you type the \
events are debounced for 300ms, and when you stop typing an API request is made to load \
locations. Then tapping on a location will load weather.
"""

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
