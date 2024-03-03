import Foundation

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
